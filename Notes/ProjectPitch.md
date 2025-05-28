
| Field     | Description                                    |
| --------- | ---------------------------------------------- |
| Document  | Initial pitch sent to Chris and Dave early May |
| Child of  | [[MasterDoc]]                                  |
| Parent of | NA                                             |
## Time-Series Based Post-Processing Approaches for Refining Accelerometer-Based Animal Behaviour Predictions

### Premise

Ecologists can sometimes mistake the output of accelerometer-based ML animal behaviour models as being a ‘fact’ of what the animal did, but it is actually just a probability prediction. While other fields of machine learning recognise the uncertainty of predictions and have a well-developed secondary analysis phase known as post-processing to correct the uncertainty, this is missing from the animal accelerometer-based behavioural classification pipeline. In this section of the chapter I will attempt to begin designing a potential scaffold for a post-processing approach to animal accelerometry, drawing in ecological understanding derived from the sequential nature of time-series data.

We do not need perfect prediction accuracy at the level of individual 1–2 second windows to arrive at ecologically meaningful interpretations. Ecological questions typically concern broad behavioural patterns (e.g., activity budgets, temporal rhythms, or habitat changes) aggregated over hours, days, or even seasons and longer-term natural cycles. These broader-scale patterns can actually tolerate a lot of inaccuracy in the raw predictions, especially if we incorporate domain knowledge to ‘smooth’ over misclassifications. By using ecologically relevant assumptions (e.g., known behaviour transitions, biological rhythms, or improbable sequences) we can fill in gaps and correct local errors, improving the consistency and ecological validity of the behavioural timeline without needing 100% accuracy at the raw prediction level.

There are multiple analysis techniques that take data sequence into account. The second component of this chapter will explore the use of Hidden Markov Models for the sequential smoothing and post-processing of raw accelerometer predictions into meaningful ecological units. This approach aims to capture the temporal dependencies inherent in animal behaviour and use these to improve the classifications.

### Hypotheses

1. Incorporating sequence information through post-processing can significantly improve the accuracy of animal behaviour predictions, compared to using raw per-window predictions alone.
2. Post-processing methods can raise the ecological validity of behaviour predictions from low-performing models to acceptable levels, even when the original per-window classification performance was poor.
3. The worse the original prediction performance, the more complex the required post-processing algorithm.
### Research Plan

1. Use in-house data we already have

| Species          | Citation                                                                                     | # Behaviours        | # Individuals |
| ---------------- | -------------------------------------------------------------------------------------------- | ------------------- | ------------- |
| Brushtail Possum | [Annett et al., 2024](https://zslpublications.onlinelibrary.wiley.com/doi/10.1111/jzo.13125) | 12                  | 4             |
| Northern Quoll   | [Gaschk et al., 2023](https://royalsocietypublishing.org/doi/full/10.1098/rsos.221180)       | 12                  | 19            |
| Echidna          | Clemente et al., 2016                                                                        | 4                   | 6 i tihnk     |
| Koala            | Sparkes et al., unpublished                                                                  | 5                   | 9             |
| Bandicoot        | Del Simone et al., unpublished                                                               | If I get this (lol) |               |

2. Define a basic ecological question to be asked from all of these datasets
    Maybe - how much walking they are doing? How active they are? How much sleep they get? Proportion of time spent doing X?

3. Design basic machine learning models to predict behaviours from data
    Set aside a test set of at least 1 individual (more the better). With the remaining individuals, design, train, and test a basic XGBoost model to predict behaviours exactly as they are following the method I designed in the original analysis of the koala data. (Just need to change from RF to XGB).

4. Trial smoothing algorithm
    Design and trial multiple smoothing algorithms, apply each of these to the test data. Compare the ground-truthed values to the base predictions and each type of smoothing. Rescore accuracy for each. The smoothing method that improves accuracy the most will be considered optimal. 
	**No Smoothing** → the predictions exactly as they come out of the model
    **Basic Temporal Smoothing** → Collapse brief, isolated behaviours into surrounding dominant class (e.g., “walk, rest, walk” would be out-voted and re-coded to the majority as “walk, walk, walk”). Use simple filters (e.g., rolling mode) to enforce temporal consistency
    **Duration-Based Filtering** → Set minimum plausible durations per behaviour (e.g., chewing ≥ 4 sec) then remove or merge the short, biologically implausible/meaningless bouts
    **Confusion Matrix-Informed Smoothing** → Use model's confusion matrix to assess likely misclassifications. Flag or correct predictions based on class-specific error rates (e.g., if chewing has a 30% confusion with walking but rest has a 5% confusion, a rest in a sequence of walking will remain unaltered, but a chewing will be recoded)
    **Transition Matrix Rule-Based Smoothing** → Build transition matrix from training data (like a Hidden Markov Model but done manually)
    **Hidden Markov Model (HMM)** → Train on labelled sequences from the training data to model probable behaviour transitions. Use Viterbi decoding to infer most likely true behaviour sequence
    **Bayesian Smoothing** → Combine prediction probabilities with prior expert ecological knowledge and then updates behaviour probabilities for each window over time using Bayesian inference… this one might be really hard to build — depending on how much ecological information I need to include (e.g., time of day impacts behavioural probabilities) this might be above my pay-grade
    **Long Short Term Memory Convolutional Neural Network (LSTM-CNN)** → like the HMM method, but with a neural network method. Might be too data deficient to work, but if I keep it shallow, might be able to avoid overfitting?

5. Answer ecological question with all methods
    Use all methods to answer the ecological question and calculate difference (count, %, etc.) from the non-post-processed results for each.

6. Determine optimal smoothing method
    Based on the increase in performance for each dataset for each smoothing method, define the pros and cons of each of the smoothing methods and decide which of them is optimal. Make suggestions for ecologists and the kinds of questions they are asking for which of the methods is more appropriate.

## Thoughts, Limitations and Concerns

- Way more cool and helpful for the research community. Could speed-run the first part with the help of an assistant and skip to this second half way sooner if desired?
- It may be a little straw-man to compare post-processing ecological outcomes to non-post-processed because not many people are asking questions that exceed “% daily budget” style investigations… And those that are asking better questions do tend to do a little bit of post-processing. Will need to look more into the literature to find some legitimate questions that have been asked
- Dependent on the data in large part whether I can verify this stuff