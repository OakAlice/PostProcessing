# Refining Accelerometer-Based Animal Behaviour Classification Machine Learning Prediction Outputs With Sequence-Informed Post-Processing

## Introduction
Machine learning models can be trained to infer specific fine-scale behaviours from animal-borne accelerometers. Over the last few decades, this method has been implemented across hundreds of species. However, despite ever-increasing sophistication of model design, performance of the behavioural classifier models retains some significant limitations. Robustly validated models indicate that individual behaviours differ in their predictability, and few classifiers obtaining high generalising performance on new data. All-together, it is clear that there is no such thing as a perfect classifier and all models will have errors. Much of the field’s recent effort has focused on optimising models to increase performance on these difficult behaviours to obtain higher performance — fine-tuning algorithms, adding sensor axes, or experimenting with novel features. While each of these steps will benefit the development of the field, there may be simpler, more parsimonious gains to be made from the data we already have.

Current analytical pipelines often treat predicted behavioural labels as discrete categories when in fact they are probabilistic predictions. In other domains of machine learning, it is standard practice to address uncertainty in the predictions through post-processing. Post-processing is a secondary application of domain-specific rules or statistical corrections to refine, or "smooth" the raw predictions. For example, post-processing is used in speech recognition to enforce syntactic plausibility, in computer vision to correct improbable object detections, and in medical diagnostics to align predicted symptoms with known disease progressions. These fields acknowledge that prediction is just one step in a longer interpretive process.

In contrast, post-processing remains largely absent from animal accelerometry pipelines. Few studies attempt to correct or refine model outputs after prediction, and even fewer incorporate ecological knowledge into this stage. Ecologists possess domain-specific knowledge specific to the context and study species that could be used to inform such post-processing and ensure ecological reliability. For example, knowledge about the realistic minimum duration of a behaviour could allow implausibly brief events to be flagged and corrected, while a knowledge of logically acceptable behavioural sequences (lay, sit, stand, run) could be used to eliminate implausible sequences (lay, run). By integrating this knowledge into post-prediction workflows, we could correct misclassifications, fill gaps, and improve the ecological plausibility of behavioural classifications without needing perfect accuracy from the classification model itself.

In this paper, we argue that post-processing represents a critical and underutilised stage in the interpretation of accelerometer-derived behavioural classifications. We demonstrate how sequence and ecologically informed post-processing can improve the consistency and ecological validity of behaviour predictions, even when the original raw classification accuracy was imperfect. This approach offers a pragmatic and simple path to increase interpretability of behaviour predictions while decreasing the burden to obtain perfect prediction in the ML stage.
## Methods
For this pilot study, a single dataset was used. Data was sourced from Sparkes et al., unpublished, a koala dataset containing labelled data from 10 individual koalas containing 14 distinct behaviours. Training data contained ground-truthed behavioural labels while the test data contained both the ground-truthed classes as well as predicted classes produced by a simple machine learning model in previous research [this is stuff I did ages ago and will be a separate paper]. 

Seven post-processing methods were compared to the control (no post-processing) predictions. 

| Method         | Description                                                                                                                                                                                                                                                                                                              |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| None (Control) | No post-processing was applied.                                                                                                                                                                                                                                                                                          |
| Mode           | A rolling window of five consecutive predictions was applied. The central prediction in each window was replaced with the modal (most frequent) behaviour within the window, smoothing out local misclassifications.                                                                                                     |
| Duration       | The 95th percentile of the minimum observed duration for each behaviour was calculated from the ground-truthed training data. In the test data, any predicted sequence shorter than this threshold was coerced to the preceding behaviour to eliminate implausibly brief events.                                         |
| Confusion      | A confusion matrix was derived from the test set to estimate the probability of misclassification between each pair of behaviours. At every predicted transition, if the likelihood of the new class being a misclassification of the preceding class exceeded 50%, the prediction was reassigned to the previous class. |
| Transition     | A transition probability matrix was calculated from the training data, capturing the likelihood of one behaviour transitioning to another. In the test data, transitions with less than 50% probability were considered biologically implausible and corrected by reverting the transition to the preceding behaviour.   |
| HMM            | A Hidden Markov Model was trained on the ground-truthed training data and used to post-process the predicted behavioural sequences, correcting local misclassifications based on the most likely underlying state sequence inferred by the model.                                                                        |
| Bayesian       |                                                                                                                                                                                                                                                                                                                          |
| LSTM           |                                                                                                                                                                                                                                                                                                                          |
For each method, performance was assessed in two ways. Firstly, performance was calculated in terms of improvement to classification performance by calculating both class-specific as well as macro-averaged Accuracy, Precision, Recall, and F1-Score. The model with the greatest increase in performance over the Control was considered the optimal method.

Secondly, the impact of these post-processing changes on the overall ecological interpretations was assessed. The deployment data from each species (that is, the unknown, unlabelled data) was predicted onto using the original machine learning classification model and post-processed with each of the trialled methods. Two simple ecological questions were devised for each dataset, and the same ecological analysis conducted on each of post-processed predictions. As there are no ground-truthed labels for these data, it is not possible to determine which of the results is more accurate, and due to the subjectivity of the ecological interpretation, nor is it intrinsically evident which would be "better". Instead, case-by-case ecologist interpretation is required to make the final call on the usefulness of the ecological results.

For each dataset, a sequence question was designed to calculate the average duration of a bout of a particular target behaviour where a 'bout' was defined as a continuous sequence of the same behaviour. Additionally, a proportion question was designed to calculate the total proportion of an individual's day spend in the target behaviour.

| Species | Behaviour | Sequence question                                  | Proportion question                                  |
| ------- | --------- | -------------------------------------------------- | ---------------------------------------------------- |
| Koala   | Walking   | What is the average duration of a ground-traverse? | What proportion of the total time is spent walking?  |
| Quoll   | Sleep     | What is the average duration of a sleep?           | What proportion of the total time is spent sleeping? |

## Results
Without post-processing, the model designed for the koala data performed with a 






## Discussion
By incorporating higher-level inference, and bringing in the sequential element of time-series data, we could achieve high performance without needing perfect classification accuracy at the level of individual seconds. In many ecological studies, the goal is not to capture moment-to-moment activity with precision anyway, but to uncover coarse-scale patterns. These questions are often robust to local classification noise and may not require high-fidelity prediction at the finest temporal scale as long as the general trends represent the underlying ecological patterns.




## Where to from here?
- 5 species (or rather, however many good datasets I can get ahold of)
- 5 x bootstrapping per species
- Get back in contact with Dr Hui Yu from Deakin to consider getting his collaboration on this chapter? He and I have already discussed coming up with some kind of project to collaborate on - though I was thinking more of behavioural clustering for him. He did mode based smoothing in some of his papers.
- Pitch this to Dr Pravna Minasandra from Max Planck Institute of Animal Behaviour? He wrote an awesome paper using hazard functions to determine the natural duration of behaviours - could use this as an additional smoothing method? I am visiting Pravna in July.
## Target Journals
- Phil Tran B --> However, this costs money after the first 6 pages...
- Open Biology --> chris is an editor here, hopefully will get nepotistic treatment
- it's a methods paper... once again, going to struggle to get into pure eco/evo journals