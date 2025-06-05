| Field     | Description                                                     |
| --------- | --------------------------------------------------------------- |
| Document  | Basic experimentation with koala data to design script function |
| Child of  | [[MasterDoc]]                                                   |
| Parent of | NA                                                              |
## Data and Methods Development
#### 28052025
- For this trial I will be using the data from the Koala project that I worked on for Gabby. In the [[ProjectPitch]] I said I would use the test data that came out of the ML model building. Using the prediction outcomes is more interesting, but without ground-truthing, I can't easily say which of them is a performance improvement.
- Okay, have done that now. Now I'm going to calculate performance (this will be a standardised method that all of them use)
- Did the **no smoothing** condition as well as the **basic (mode based) smoothing** (like I did for my honours), setting up the very basic code for performance checking and visualisation (essentially directly ripped from the gabby analysis). 
- I have now set up a very basic html report that compares the smoothing methods and makes a consolidated statement about which of them is best. I did this because I have traditionally found that consolidating my results is a source of confusion. By automatedly drawing them together, I remove that issue.
- Am I speaking too soon? I think this idea is going to be a massive success!!
#### 30052025
I'm currently in the field watching over Romeo the Western Grey. While I'm sitting here I figured I might be able to work on some of my code. Today I can work on the **duration-based smoothing**. My idea behind this is that you figure out the durations of behaviours in the training data, extract the min, max, and average, and then use these values to smooth over the predictions to match.
- This obviously makes the assumption that the behaviours in the training data are representative, which is problematic in many ways... but I can't get around this so I just have to go with it.
- The min for all the behaviours in the koala data was 1... should I include this or omit it? Including it makes my duration smoothing method impossible. If I omit it, my minimum duration ticks up to 2 for a lot of behaviours but then like 70 seconds for Tree Sitting, even though a 10 second sit actually would be very legitimate.
- I suppose the issue I didn't really consider is that an animal *can* reasonably do anything for 1 second even though it isn't ecologically interesting / relevant. So my score performance is probably going to drop for a lot of behaviours if I wont let it do anything for 1 second. BUT. That might be a cost I have to bear. And I can list that as a limitation for this specific method.
- An idea would be to make a frequency distribution and then select the 95th percentile... then I know that I'm only missing 5% of them.
	- Okay I did this, but that was 1 for most of them! 1 is just dominating the frequencies totally! When I exclude 1 and do the 95%, it looks way better. Except for some behaviours that have a far too long cut-off. ==I had to manually adjust a few numbers. This isn't really acceptable... will need to consider this a lot more.==
- Just checked the results and eek. It smoothed over the top of all my infrequent behaviours resulting in a largely NA performance for the less frequent behaviours...
- So far this seems to actually be dropping the performance slightly. I wonder whether this is an artefact of the (slight) possibility that the original predictions have some leakage in them and are therefore not *actually* totally independent...
- ![[Pasted image 20250530201721.png]]
I've now started on the **Confusion Smoothing** method and have quickly reached another thinking point. I was able to extract the miscalssification likelihood from the confusion matrix so I know, given any predicted class, what the probability is of it actually being a different class. But ==how do I identify the "probably wrong" instances?== I could do it with:
- mode approach - anything not the same as the mode of 5 gets investigated as possibly misclassified. 
	- pros: likely to catch all the single errors, easy
	- cons: too basic? there may be multiple mis-classifications in a row which wouldn't trigger the flip
- break approach - whenever the behaviour changes, check if that change was a misclassification
	- pros: likely to catch all the single errors, also easy
	- cons: need to think about this more.... going to call it a night...
#### 01062025
Upon describing this problem to Chris, I realised that the issue is that I have 2 simultaneous tasks.
1. Identify instances that might be incorrectly labelled
2. Determine whether they need to be flipped.
What I should do is find a bunch of papers that have looked at post-processing in other domains and then copy them. For now, I am going to make this as simple as possible by looking at change points. Whenever there is a behaviour change, assess whether it could be a misclassification. 
- ==Justification for this is that transition windows are very messy and probably get misclassified more often than an in-sequence established behaviour.==
- Well... I just tried that now and it sucked. As in, it made the performance so much worse than with no smoothing - nearly across board... will have to double check my logic for this system.
	- Updated it by checking whether the change-point was a switch to a new continuous sequence (so if its the same as the one before or after it, leave it) and that improved performance a lot - though it's still worse than nothing in some cases... ==will need to return to this method to improve it when I've read some literature==

The next one for me to attempt is **Transition Matrix Smoothing** which I imagine will be like a manual version of the HMM. As in, I will manually calculate the probability of one behaviour type transitioning into another within the training data.
- WAIT. I just had a thought. The training data hasn't necessarily been collected consecutively and this - and the other sequence-based methods - rely on it being as natural a representation of the true behavioural sequences as possible. I will have to check how much of the labelling is continuous... 
- Okay have done that and found quite strange results. Did I do every 0.5 seconds for the predictions huh? I've made it so that there will be a "break" if there is more than 2 seconds between samples but will make this user defined.
- So now I'm making a frequency plot which seems to indicate that most of the data has a sequence of only a few seconds long.
- ![[Pasted image 20250601182724.png]]
- I realised while doing this that I've been using the test data for everything but I actually have access to the training data which has way more info. I am switching my other methods to "learn" from the training data where such a step is included.
	- Okay this looks way better
	- this also removed the step of having to manually change the behaviour durations in the duration smoothing method because they were way better! Yes!!!
- Next question is asking how many of these contain transitions vs being purely one behaviour?
	- ![[Pasted image 20250601184656.png]]
	- Okay, not looking too great. Over 90% just have one behaviour. That SUCKS. Okay, so what are the times between these? What if I increased my break duration to like 10 seconds? 
		- I played around a bit until I got to a place I felt I could gather information from. This will be totally dataset dependent, with some datasets containing many long continuous sequences and transitions, and, at the other end, others having intentionally not collected transitions - for example.
- I have now gone ahead calculated the transition probability between any two combinations of behaviours seen in the training data (==I should probably also be accounting for combinations not seen in the training data==) and used this to assess the transitions seen in the predicted data. I have flagged all transitions with a probability below a user-defined threshold as "suspicious". But now what? Given that an event is suspicious... I shouldn't just automatically flip it to a more probable event.
	- In the durations smoothing, which has a similar idea, when I encountered a suspicious event, I changed it to be the most recently acceptable behaviour... do I do that here too?
	- Damn it. For every time this made it better, it also made it worse. Ugh. The macro-average is better than Duration Smoothing at least, but not better than doing nothing.
	- ![[Pasted image 20250601201638.png]]

- ==Please note that, as a quirk of the data Gabby has labelled, it is considered highly improbable that sleeping would transition to wakeful sleeping (she didn't record these events). All kinks like this could *easily* be worked out by an ecologist even though they will unfairly hamstring my analysis.== %% Note this in the paper %%

Now that I've got a basic system working for these manual methods I can move on to the ML methods - the first of which is an **HMM**. I then read some websites and papers to understand what I'm doing but then realised I was too tired to take it in and stopped for the night instead.
#### 03062025
The decision I hadn't even been thinking about would be whether or not to include the feature information in this secondary smoothing. If I could look at the features again, maybe my predictions would be way better? I don't really want to do that though because its delving into prediction more than post?
- So, therefore, making the decision to only give the models access to the time, ID, and predictions, what can I do?
While this hasn't been done in the ecology field yet, I can draw on examples from other time-series sequence fields such as speech recognition. I have started searching for other papers where this has been done. But then the internet at Fowler's ran out and I couldn't access anything anymore.
#### 04062025
Okay the HMM sucked ASS. It didn't do what I expected and actually amplified errors?? According to Chat-GPT this is an expected result and to improve it I need to feed the HMM model-predicted class probabilities (instead of the labels). Damn it. I didn't calculate those I don't think... but it would generally improve all the methods if I were to do this. So possibly I should recalculate the test results now.
- I will try that now.
- Holy fuck I'm pulling out my hair what is going on. I can't find any tutorials that will show me what I want to do and I'm starting to doubt the validity of my task. Resorted to using claude and chat-gpt but those dumb fucks just gave me nonsensical code with non-existent variables.
- https://www.numberanalytics.com/blog/deep-understanding-hidden-markov-models-sequence-analysis
	- ![[Pasted image 20250604201841.png|400]]
- https://cran.r-project.org/web/packages/seqHMM/vignettes/seqHMM.pdf
	- In the context of hidden Markov models, sequence data consists of observed states, which are regarded as probabilistic functions of hidden states. Hidden states cannot be observed directly, but only through the sequence(s) of observations, since they emit the observations on varying probabilities.
	- ohhhhh okay. So I'm starting to think that I can't set my true class as the observed and the hidden state. I need to have the predicted class be the observed state with the true class as the hidden state... I dont have predicted classes for my training data though... but I could make them????
	- Okay yeah! I was using an unsupervised package but when I switched to a package that allowed supervised leanring and added in some predictions into my training data, I got the kind of code I was looking for.
		- I am however worried that this is a highly illegitimate thing to do... considering that I predicted onto my own training data, this is going to have a much higher prediction accuracy than the test data, and that will be higher than the deployment data again... so? Am I actually learning anything?
		- Huh. Bellowing is massively over-predicted in the outputs. Is that something I can change?
			- Looks like yeah, this is something that I can manually adjust - but I dont want to be doing that at this stage.
	- Managed to fix it last thing before I went to bed and its working now... albeit not well.
#### 05062025
Now I am going to get started on the Bayesian smoothing. What does this even mean?
https://www.seascapemodels.org/rstats/2017/06/18/estimating-popn-decline.html
- 



==Note, for the ecological question I should be using the deployment data not the test data==







**Tasks for next time:**
- [ ] Visualisation of sequence order
- [ ] Basic ecological question to compare results of
- [ ] Find a bunch of timeseries post-processing papers from other domains 
- [ ] Second way to assess performance other than F1 score (as in, something that looks at the ecological meaningfulness of the data)
- [ ] Create the best possible smoothing method that I can think of.



#### Thoughts and Conclusions
- Conclusion for the paper will probably be that the best post-processing method depends on the scale of your behaviours, and the question you're trying to ask. There is no one size fits all in ecology. We need to be thinking about our data in context of the question it is asking. And its actually a very manual process.
- For example, in a highly variable model with lots of short behaviours, maybe you dont want to smooth in post after all? But for a model with generalised behaviours, it can probably help a lot.
- We need to be looking at the scale of the questions we're asking. Is it more important to be accurate or interpretable?





Best possible method would be to have an ecologist define all the parameters and then combine all the different types of smoothing and then for anything thats flagged as suspicious, it visualises the data for you, and you can recode it.




Hey Dave and Chris!

Just got back from our kangaroo collar deployment and my ASSAB conference! Dave is at a conference this week, but if it still works for everyone - we could pencil a meeting for sometime early next week? :) 

Before we meet, I've pulled together a draft report to explain my prelim results from the first dataset for my fourth chapter. I'm super excited about this, but - as I've now learnt - the trend between my optimism levels and my results being legitimate is far from positively linear ahah, and this will definitely need some critical review!

Draft: [[PilotReport]]

Thank you and hope you have a great time at the conference Dave.

Regards,
Oak