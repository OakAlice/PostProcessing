# Post-Processing
In animal accelerometer-based behavioural classification research, the majority of the attention has (understandably) been placed on the collection of the data and the building of the models with relatively little attention given to what to do with the data once we have it. In this chapter I am going to experiment with using sequential context information to improve classification performance.

The following workflow was designed to build predictive models, apply smoothing methods to raw predictions, and assess their ecological utility.

The data was pre-formatted from the original data sourced from online repos into standardised format in alternate github repository: [https://github.com/OakAlice/DataReformatting](https://github.com/OakAlice/DataReformatting)

## Repository Structure
Arranged roughly in the order you'd need them.

- **Scripts/**
  - `MainExperiments.R`: Structures and calls the rest of the code.
  - `SequenceReport.R`: Summarises the sequence traits from each of the datasets.
  - `PerformanceTestingFunctions.R`: Core performance metrics.
  - `SequenceIdentificationFunctions.R`: General functions for finding the continuous stretches in the data.
  - `PlottingFunctions.R`: Visualisation tools.
  - **ModelBuilding/**
    - `GenerateFeatures.R`: Code to generate the features across the labelled data.
    - `GenerateFeatures_Functions.R`: Functions for feature extraction from raw accelerometer samples.
    - `BuildModel.R`: Trains, tunes, and evaluates Random Forest model for each of the formatted datasets.
    - `HPOFunctions.R`: Functions for optimising the model design
  - **SmoothingMethods/**
    - `NoSmoothing.R`: Baseline, raw predictions.
    - `ModeSmoothing.R`: Majority vote sliding window smoothing.
    - `DurationSmoothing.R`: Filters out unrealistically short events.
    - `ConfusionSmoothing.R`: Corrects systematic classifier confusions.
    - `TransitionSmoothing.R`: Removes improbable transitions.
    - `HMMSmoothing.R`: Applies Hidden Markov Models for temporal correction.
    - `BayesianSmoothing.R`: Bayesian smoothing based on transition probabilities.
  - **Comparisons/**
    - `ComparingSmoothing.R`: Calls the following R markdown.
    - `ComparingSmoothingReport.Rmd`: R markdown showing the results for a single dataset.
    - `ComparingComparisons.R`: Calls the following R markdown.
    - `ComparingComparisonsReport.R`: Meta-comparison of smoothing method performance and plots.
  - **EcologicalCaseStudy/**
    - `MainCaseStudy`: Runs all the code relevant to the casestudy
    - `GenerateSpecificFeatures`: Generate the features on the unlabelled data
    - `GenerateEcologicalPredictions.R`: Generate the predictions
    - `CaseStudySmoothing.R`: Smooth the predictions
    - `CaseStudyComparison.R`: Answer the ecological question with each of the smoothing results
- **Data/**
    - Hard to upload the data due to file sizes and git limits but uploaded one data example (data sourced from [Ferdinandy et al., 2020](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0236092])
