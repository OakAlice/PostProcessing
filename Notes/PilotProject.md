| Field     | Description                                                     |
| --------- | --------------------------------------------------------------- |
| Document  | Basic experimentation with koala data to design script function |
| Child of  | [[MasterDoc]]                                                   |
| Parent of | NA                                                              |
## Data and Set Up
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
![[Pasted image 20250530201721.png]]
I've now started on the **Confusion Smoothing** method and have quickly reached another thinking point. I was able to extract the miscalssification likelihood from the confusion matrix so I know, given any predicted class, what the probability is of it actually being a different class. But ==how do I identify the "probably wrong" instances?== I could do it with:
- mode approach - anything not the same as the mode of 5 gets investigated as possibly misclassified. 
	- pros: likely to catch all the single errors, easy
	- cons: too basic? there may be multiple mis-classifications in a row which wouldn't trigger the flip
- break approach - whenever the behaviour changes, check if that change was a misclassification
	- pros: likely to catch all the single errors, also easy
	- cons: need to think about this more.... going to call it a night...



**Tasks for next time:**
- [ ] Visualisation of sequence order
- [ ] Basic ecological question to compare results of
- [ ] Second way to assess performance other than F1 score (as in, something that looks at the ecological meaningfulness of the data)












Hey Dave (and cc'ed Chris)!

Hope you've been well!

Just got back from our kangaroo collar deployment and my ASSAB conference! Had a great time but glad to be back in the office now :) I'm home for 2.5 weeks until off to Europe so thought it would be a good idea to fit in a meeting if possible?

I've made some decently sized decisions regarding my thesis and would be good to get your thoughts, Dave. Biggest update is that I went ahead on my Post-Processing/Sequencing project and - to my massive surprise - it went really really well! I worked on this while I was out in the field and have pulled together a draft report to explain the preliminary results from the first dataset. Would be great to get some feedback on this before I progress into cross-validation and additional datasets. I've attached the prelim draft below:

Draft: XXXXXX
Git: XXXXXX

I'm super excited about this, but (as with the last chapter) there's probably some glaring flaws I'm looking straight past and will be great to have a chat about it!

Thanks,
Oak