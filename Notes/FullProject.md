- 20/06: Sourcing data from the BEBE paper (which, by the way, is amazing -> https://movementecologyjournal.biomedcentral.com/articles/10.1186/s40462-024-00511-8#Sec2). I am going to use this data for the full study. I downloaded all the "formatted" data from the zenodo link: https://zenodo.org/records/7947104
	- wtf are they in such weird formats?? This isn't half as user friendly as they claim it is
	- All the data are stored as 'clips' - does that refer to videos?
	- Looks like they have removed 'Time'... which means I have limited ability to discern true transitions... in all cases where I can get the raw data with Time, I should do that.
	- Therefore, for some of the datasets I went back to the original papers and extracted the original data instead.
	- I set up Vehkaoja_Dog and Ladds_Seal to run for ages.
- 22/06: It is now Sunday evening and I have processed features for the two named datasets and now will build a basic ML model for each of them.
	- ==I will definitely need some kind of report looking at the "realisticness" of the training data. Potentially I could look at how much of the data occurred in sequence and then have another metric of how many transitions were represented? I think this will be an important co-variable.==
- 23/06: Breathe it out breathe it out breathe it out. Trying not to have a panic attack about amberley. Hyperfocus on work?
	- I started tuning the model for the dogs and for some reason it sucks? I've stopped it and having a go on a subset of data until I find if there's a bug here?
	- Something is definitely wrong, the performance is so low... I need to step inside the parameters and see where the error is.
- 24/06: Have also expanded into the new datasets that have very specific, and frankly not that useful behavioural labels. Because I haven't completed the "behaviour quality" pre-processing project yet, I don't have strong legs to stand on regarding rejecting the existing behavioural categories. However, the performance is appalling. Therefore, do I go to the "generalised" labels which will do better? Conflicted...
	- Changed it to give probability and that meant updating a few things
	- changed to weighted by class prevalence 
- 25/06: **Alright relatively major update in thinking here**. I am now progressing with the seal data and finding that the starting performance is so appalling, the post-processing is fighting such a steep up-hill battle it has no hope at all. And ==the reason why its doing so bad is because the behavioural categories are practically meaningless --- both as demarcations and in terms of natural sequencing. Do I group them to ecological level just to see it do better?==
	- I've now run the seal and the Veh_dog through, both of which kind of tanked. But how would I fix it in any way that isn't totally non-arbitrary?
	- I will try to source some other non-arbitrary datasets for now... e.g., going to get the echidna data from Clemente et al., 2016 up and running now.
	- I've had so little sleep across the last week, my brain is fuzzy and eyes hurt.
	- Went through my hand-drive and grabbed as many datasets as I could as well. Going to just try to smash through them all over the next week and then make the decision of what to do about poorly predicted datasets. I have tabulated my progress for tracking below.
		- The one thing I can't find is how to link the Minasandra observations with the raw data since the times are different in both files. I tried reading through his github (https://github.com/pminasandra/hyena-acc/tree/master) and even that left me with few clues. ==will return to this later==
		- Instead, began feature processing for the other species

| Dataset               | Raw | Formatted | Feature         | Model | Smoothing |
| --------------------- | --- | --------- | --------------- | ----- | --------- |
| Sparkes_Koala         | x   | x         | x               | x     | x         |
| Vehkaoja_Dog          | x   | x         | x               | x     | x         |
| Ladds_Seal            | x   | x         | x               | x     | x         |
| Smit_Cat              | x   | x         | x               | x     | x         |
| Studd_Squirrel        | x   | x         | x               | x     | x         |
| Clemente_Echidna      | x   | x         |                 |       |           |
| Pagano_Bear           | x   | x         | in prog         |       |           |
| Jeantet_Turtle        | x   |           |                 |       |           |
| Minasandra_Hyena      | x   |           |                 |       |           |
| Yu_Duck               | x   | x         | x               | x     | x         |
| Makaewa_Gull          | x   | x         | (6 individuals) | x     | x         |
| Dunford_Cat           | x   | x         | x               | x     | x         |
| Ferdinandy_Dog        | x   | x         | x               | x     | x         |
| HarveyCaroll_Pangolin | x   | x         | x               | x     | x         |
| Hanscom_KangarooRat   | -   | -         |                 |       |           |
- 26/06: I'm one file away from extracting the echidna data (forgot that it was running and closed laptop oops) and have nearly completed the feature generation for the datasets I extracted yesterday. Today I will:
	- [x] Finish extracting echidna data
	- [x] Email Dr Hui Yu re: collaboration (meeting next week?)
	- Another thought I had is that I don't necessarily have to make "good" models that can transfer between individuals. In the cases where the training data and the deployment data is drawn from the same individuals, I can just make chron models... which would make them look a lot better... but then... no point really I think. ==Nah. Just fix the behs.==
	- **THOUGHT!!** When my test data is as cooked as the training data (i.e., neither of them are natural) there's almost nothing that can be done to improve them as a sequence because their sequence is fundamentally not oriented in reality... eek. Bad news.
		- Therefore, to actually test whether this is working, I need a dataset with extensive naturally annotated data... I don't like the fact that I'm thinking I'll have to use my own cat data.
- 27/06: After doing 3MT today, I'm back on the grind. Will just have to keep grinding through datasets until I collect enough that show a performance gain? I have decreased my standards for dataset inclusion in hopes that a broader range of species will pop something out. Also need a single (or few) metric(s) that I can use to measure the sequential-ness of the labelled data.
* 29/06: **What I really need to think about is how I'm going to statistically analyse my results** to determine whether there is a significant performance improvement or not... e.g., because I'm not cross-validating within my datasets, I'm not getting error-bars... going to think about whether I really do actually have to hold-out on myself like that...
	* Chris and Dave thought it was overkill if I leave it out due to over-fitting/information leakage issues but... If I use the predictions on the training data, they will be unnaturally good compared to usual performance on deployment data therefore I won't see performance gains as a result of post-processing anyway.
	* Based on the results so far (image below) ==Bayesian smoothing is thus far emerging as the clear leader lmao== but the confusion matrix method doesn't look to be having any effect... and when it does, a negative effect. I still believe in the potential of this method... so will have to revisit that to refine the logic of it.

![[Pasted image 20250629091716.png|400]]
* Tried the kalman filter this morning but issue arose when model did not predict all possible classes, and then there will be none of that class in the transition matrix... so there isn't a way to fit it into the probability of the kalman filter... annoying... will deal with this on Monday.
	* In the meantime, need to get back to the problem of determining which of the smoothers was optimal in a statistically significant way. And that will require the variable of naturalisticness... so need to work on that now.
	* The obvious ones are:
		* Average number of transitions per sequence
		* Average length of sequence
		* Proportion of all sequences that have multiple behaviours
		* Transitions / second as the transition rate (how quickly do animals flip between behaviours when they are recorded...)
	* My variables are: 
		* F1: Macro-average F1-score for each species and each smoothing type
		* Transition_Rate: Transition/second within each continuous sequence
		* Prop_Transitions: How many training sequences contained transitions
	* Exploratory, I can begin by plotting these against each other? But to do that... I need to get the relative improvement / change from control.
#### Trying out some basic stats on the results so far
- If I look at the relative improvement from control across the datasets and just make a very simple lm I get that Bayesian smoothing is significantly better...
![[Pasted image 20250629113733.png|400]]
- Adding into that some of the sequence stats that I calculated earlier made Bayes more significant but none of the other variables themselves became significant... So... that means that I have a barely significant result... but it is something! Keep working on it! Yay!
![[Pasted image 20250629114423.png|500]]
- Looked at mixed effects with Species as Random, and that made bayesian and duration both highly significant. Looking very promising.
	- For now will just continue adding datasets to the mix and begin working on the introduction

- 30/06: Pagano_Bear has so much data it ran for days and still didn't finish generating features. Far out... So I'm thinking that I'm going to have to crop it and only take the first half of all behaviours or something... but then that would destroy sequence information... Maybe just do it all since I'm working on other things for the next 2 days anyway.
- 1/07: Hanscom_KangarooRat doesn't have available raw training data, so I'm going to have to use their feature data. I can use this to build a model anyway. It doesn't give me as much control, but is fine. Just have to remember that this is different. And have to assign column names so it'll work. There's also no time as far as I can see which is frustrating... Do I bother? I wanted to because it has unlabelled data as well, which is quite rare.
	- Wait... frick me. There's no ID, no Time, and the unlabelled data has SO many more variables than the labelled... and they're not labelled. Going to have to abandon this dataset... or maybe email them?
	- Emailed the lead author... may or may not get any response from that.
		- Okay he responded saying he would only give me the data if he was an author on the paper. That annoyed me so much ugh. Like you're not getting authorship in exchange for sharing non-vital data? Would have to give authorship to every single dataset then... I guess there's no reason to not do that... should I have offered authorship to the Ferdinandy team...? Probably I should have actually. Fuck. Asking Dave and Chris about that now.
- 2/07: Going to try starting to write the introduction up properly today and see if I can get a full draft before I leave for Europe. Feeling a lot of mental blockage and difficulty convincing myself to do this but hopefully will get a roll on and it'll be easier than I think???
	- Did some better stats today figuring out which of my interactions are important.
![[Pasted image 20250702123036.png]]
- Annoyingly, once I account for the interactions, I get different effects:]
| **smoothing_typeHMMSmoothing** | –0.445 | 0.151 | –2.95 | 0.0045 | ** |  
| **smoothing_typeLSTMSmoothing** | –0.344 | 0.150 | –2.29 | 0.0255 | * |  
| **smoothing_typeHMMSmoothing:Transition_Rate** | 14.86 | 5.25 | 2.83 | 0.0063 | ** |  
| **smoothing_typeHMMSmoothing:Prop_Transitions** | 0.898 | 0.294 | 3.06 | 0.0033 | ** |  
| **smoothing_typeHMMSmoothing:Transition_Rate:Prop_Transitions** | –24.31 | 6.80 | –3.57 | 0.0007 | *** |
Other terms (main effects and interactions) were not statistically significant (_p_ > 0.1).
- I think this is kind of 2 different questions though. 1 I'm looking at which one improves it, with no covariables. And then I look at the effect of sequences. Cool. 
#### Had been calculating relative change wrong
- Damn it. I had been doing ((score - baseline) / baseline) but I actually just want score-baseline. This is what we get now... and the stats don't change by much
![[Pasted image 20250702141035.png]]
- 3/7: Have cracked the shits with pagano dataset. 1 more individual to go. Do I wait? It's consumed my desktop for nearly a week. Yeah gotta wait for it... Will do the goat dataset instead.



- Paper will have 2 points. 1 will be that post-processing can provide performance gains / changes. 2 will be that we have been treating this data like discreet moments in time, not as sequences, and we need to go back to treating it like sequential data... maybe I could try filling out the introduction this week?
- ==redo all of this but without the overlap between windows?==
