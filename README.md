# Post-Processing
In animal accelerometer-based behavioural classification research, the majority of the attention has been placed on the collection of the data and the building of the models with relatively little attention given to what to do with the data once we have it. In this project, we use information inherent in the training data (sequential order of behavioural observation) to place predictions in context and account for classifier error. The idea is similar to that which is already used widely in speech-to-text recognition (example below).

![The concept behind post-processing](post_processing_idea_langauge.png)

The following workflow was designed to build predictive models, apply smoothing methods to raw predictions, and assess their ecological utility.

## Data
The included data was pre-formatted from the original data sourced from online repos into standardised format in alternate github repository: [Temporarily redacted for anonymisation purposes]. The koala data used in the case-study was sourced from a collaborator. Data originally analysed as part of [Between the Trees: Quantifying Koala Ground Movement for Conservation Action](https://www.mdpi.com/2076-2615/15/24/3537).

## Repository Structure
Repo is split into a few major sections.

- **Scripts/**
  - `MainExperiments.R`: Structures and calls the rest of the code.
  - Several function scripts that will be used throughout 
  - **ModelBuilding/**
    - Scripts for preparing data, training, tuning, and testing Random Forest models
  - **SmoothingMethods/**
    - Self-contained post-processing smoothers
  - **Comparisons/**
    - Markdowns for undertaking statstical comparisons of the effect of the post-processing methods
  - **EcologicalCaseStudy/**
    - Use the post-processing methods in an applied case-study to determine the downstream effects of post-processing on answering ecological questions
