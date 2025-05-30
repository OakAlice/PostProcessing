| Field     | Description                                                     |
| --------- | --------------------------------------------------------------- |
| Document  | Basic experimentation with koala data to design script function |
| Child of  | [[MasterDoc]]                                                   |
| Parent of | NA                                                              |
## Data and Set Up
#### 28052025
- For this trial I will be using the data from the Koala project that I worked on for Gabby. In the [[ProjectPitch]] I said I would use the test data that came out of the ML model building. Using the prediction outcomes is more interesting, but without ground-truthing, I can't easily say which of them is a performance improvement.
- Okay, have done that now. Now I'm going to calculate performance (this will be a standardised method that all of them use)
- Did the no smoothing condition, setting up the very basic code for performance checking and visualisation (essentially directly ripped from the gabby analysis). 
- I have now set up a very basic html report that compares the smoothing methods and makes a consolidated statement about which of them is best. I did this because I have traditionally found that consolidating my results is a source of confusion. By automatedly drawing them together, I remove that issue.
- Am I speaking too soon? I think this idea is going to be a massive success!!
#### 30052025
I'm currently in the field watching over Romeo the Western Grey. While I'm sitting here I figured I might be able to work on some of my code. Today I can work on the duration-based smoothing. My idea behind this is that you figure out the durations of behaviours in the training data, extract the min, max, and average, and then use these values to smooth over the predictions to match.
- This obviously makes the assumption that the behaviours in the training data are representative, which is problematic in many ways... but I can't get around this so I just have to go with it.
- The min for all the behaviours in the koala data was 1... should I include this or omit it? Including it makes my duration smoothing method impossible. If I omit it, my minimum duration ticks up to 2 for a lot of behaviour. I can't really just keep removing these...



**Tasks for next time:**
- [ ] Visualisation of sequence order
- [ ] Basic ecological question to compare results of
- [ ] Account for the fact that we generally consider things on a minute - 5 minutes scale












Hey Dave (and Chris)!

Hope you've been well!

Just got back from our kangaroo collar deployment and ASSAB conference, where I presented results of my Open Set chapter and got some positive feedback yay.

I've made some decently sized decisions regarding my thesis and would be good to get you in the loop, Dave. Biggest update is that I went ahead on my Post-Processing/Sequencing project and - to my massive surprise - it went really really well! I've been working on this for a few weeks now and have pulled together a draft report to explain the preliminary results from the first dataset. Would be great to get some feedback on this before I progress much further. I've attached below:

XXXXXX

I'm home for 2.5 weeks until I'm off to Europe for the SEB conference where I'll be presenting results of the Validation Review and then visiting the Max Planck Institute of Animal Behaviour for a few days of chat. If you're both available, do you think we would be able to fit in a meeting in that window?

Thanks,
Oak