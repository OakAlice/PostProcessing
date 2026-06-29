# Ecological CaseStudy ----------------------------------------------------
# for the case study analysis
set.seed(1000)

base_path <- "C:/Users/oaw001/OneDrive - University of the Sunshine Coast/02.PostProcessing"
# base_path <- "C:/Users/PC/OneDrive - University of the Sunshine Coast/PostProcessing"

#install.packaged("pacman")
pacman::p_load(
  tidyverse, 
  data.table,
  future,
  future.apply,
  HMM,
  torch,
  zoo,
  lubridate,
  rlang,
  tsfeatures,
  lubridate,
  ranger
)

sample_rates <- list(Sparkes_Koala = 50,
                     Clemente_Echidna = 10)

# Functions ---------------------------------------------------------------
source(file = file.path(base_path, "Scripts", "SequenceIdentificationFunctions.R"))
source(file = file.path(base_path, "Scripts", "ModelBuilding", "GenerateFeatures_Functions.R"))
source(file = file.path(base_path, "Scripts", "PlottingFunctions.R"))
source(file = file.path(base_path, "Scripts", "SmoothingMethods", "SmoothingFunctions.R"))
source(file = file.path(base_path, "Scripts", "EcologicalCaseStudy", "GenerateSpecificFeatures.R"))

# Generate predictions for ecological unlabelled data ---------------------
source(file = file.path(base_path, "Scripts", "EcologicalCaseStudy", "GenerateEcologicalPredictions.R"))

# Smooth the data with each of the methods --------------------------------
source(file = file.path(base_path, "Scripts", "EcologicalCaseStudy", "CaseStudySmoothing.R"))

# Compare the results of the smoothing ------------------------------------
# define a target activity to analyse
target_activity <- "Locomotion"
source(file = file.path(base_path, "Scripts", "EcologicalCaseStudy", "CaseStudyComparison.R"))

