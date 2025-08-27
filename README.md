# Post-Processing
In animal accelerometer-based behavioural classification research, the majority of the attention has (understandably) been placed on the collection of the data and the building of the models with relatively little attention given to what to do with the data once we have it. In this chapter I am going to experiment with using sequential context information to improve classification performance.

The following workflow was designed to standardise diverse datasets, build predictive models, apply smoothing methods to raw predictions, and assess their ecological utility.

## Repository Structure

- **Scripts/**
  - **DataFormatting/**
    - `DatasetCharacteristics.R`: Extracts dataset-level traits (e.g., sample rate, behaviours, duration).
    - `GenerateFeatures_Functions.R`: Functions for feature extraction from raw accelerometer samples.
    - `<species>_Formatting.R`: Species-specific formatting scripts. Converts from the raw data to a standard format and generates features from windows.
  - **ModelBuilding/**
    - `BuildModel.R`: Trains, tunes, and evaluates Random Forest model for each of the formatted datasets.
  - **SmoothingMethods/**
    - `NoSmoothing.R`: Baseline, raw predictions.
    - `ModeSmoothing.R`: Majority vote sliding window smoothing.
    - `DurationSmoothing.R`: Filters out unrealistically short events.
    - `ConfusionSmoothing.R`: Corrects systematic classifier confusions.
    - `TransitionSmoothing.R`: Removes improbable transitions.
    - `HMMSmoothing.R`: Applies Hidden Markov Models for temporal correction.
    - `BayesianSmoothing.R`: Bayesian smoothing based on transition probabilities.
    - `LSTMSmoothing.R`: Neural-network-based sequence smoothing.
  - **Comparisons/**
    - `ComparingSmoothing.R`: Collects metrics across smoothing methods.
    - `ComparingComparisons.R`: Meta-comparison of smoothing method performance.
  - **Utility Functions/**
    - `PerformanceTestingFunctions.R`: Core performance metrics.
    - `EcologicalTestingFunctions.R`: Ecological-useful behaviour metrics.
    - `PlottingFunctions.R`: Visualisation tools.
- **Data/**
    - Hard to upload the data due to file sizes and git limits but uploaded one data example (data sourced from (Ferdinandy et al., 2020)[https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0236092])
