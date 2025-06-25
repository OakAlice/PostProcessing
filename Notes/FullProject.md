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

| Dataset          | Raw | Formatted | Feature | Model | Smoothing |
| ---------------- | --- | --------- | ------- | ----- | --------- |
| Sparkes_Koala    | x   | x         | x       |       |           |
| Vehkaoja_Dog     | x   | x         | x       | x     | x         |
| Ladds_Seal       | x   | x         | x       | x     | x         |
| Smit_Cat         | x   | x         |         |       |           |
| Studd_Squirrel   | x   | x         |         |       |           |
| Clemente_Echidna |     |           |         |       |           |
| Pagano_Bear      | x   | x         |         |       |           |
| Jeantet_Turtle   | x   |           |         |       |           |
| Minasandra_Hyena | x   |           |         |       |           |
| Yu_Duck          | x   | x         |         |       |           |
| Makaewa_Gull     | x   |           |         |       |           |
