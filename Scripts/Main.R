# Main Script -------------------------------------------------------------

# base_path <- "C:/Users/oaw001/OneDrive - University of the Sunshine Coast/PostProcessing"
base_path <- "C:/Users/PC/OneDrive - University of the Sunshine Coast/PostProcessing"

#install.packaged("pacman")
library(pacman)

p_load(tidyverse, 
       data.table,
       caret,
       ggplot2,
       HMM,
       torch,
       tictoc,
       zoo,
       lubridate,
       rlang,
       tsfeatures)

# Define variables for this run -------------------------------------------
species <- "Ladds_Seal" # dataset name
target_activity <- "swimming" # behaviour that the ecological analyses will be about

# Format Data -------------------------------------------------------------
# collecting the data from various sources and formatting it to standardised structure
source(file = file.path(base_path, "Scripts", "DataFormatting", paste0(species, "_Formatting.R")))

# Make the Model ----------------------------------------------------------
# tune, train, and test a model and generate predictions on the test data
source(file = file.path(base_path, "Scripts", "ModelBuilding", "BuildModel.R"))

# Compare the smoothing options -------------------------------------------
# Important functions -----------------------------------------------------
source(file = file.path(base_path, "Scripts", "PerformanceTestingFunctions.R"))
source(file = file.path(base_path, "Scripts", "EcologicalTestingFunctions.R"))
source(file = file.path(base_path, "Scripts", "PlottingFunctions.R"))

# No Smoothing ------------------------------------------------------------
# assess performance and base stats of the raw predictions
source(file = file.path(base_path, "Scripts", "SmoothingMethods", "NoSmoothing.R"))

# Basic Temporal Smoothing ------------------------------------------------
# doing the most basic mode-based smoothing
source(file = file.path(base_path, "Scripts", "SmoothingMethods", "ModeSmoothing.R"))

# Duration Smoothing ------------------------------------------------------
# removing too-short instances based on the 95th percentile durations
source(file = file.path(base_path, "Scripts", "SmoothingMethods", "DurationSmoothing.R"))

# Confusion Smoothing -----------------------------------------------------
# correcting for flaws in the prediction system
source(file = file.path(base_path, "Scripts", "SmoothingMethods", "ConfusionSmoothing.R"))

# Transition Smoothing ----------------------------------------------------
# removing improbable behavioural transitions
source(file = file.path(base_path, "Scripts", "SmoothingMethods", "TransitionSmoothing.R"))

# HMM Smoothing -----------------------------------------------------------
# using secondary Hidden Markov Model to smooth 
source(file = file.path(base_path, "Scripts", "SmoothingMethods", "HMMSmoothing.R"))

# Bayesian Smoothing ------------------------------------------------------
# Bayes rules to smooth transitions
source(file = file.path(base_path, "Scripts", "SmoothingMethods", "BayesianSmoothing.R"))

# LSTM Smoothing ----------------------------------------------------------
# Using a basic neural network to learn the natural sequences of behaviour
source(file = file.path(base_path, "Scripts", "SmoothingMethods", "LSTMSmoothing.R"))



# Comparing Smoothing Performances ----------------------------------------
# this will pull out all the metrics tests and build a report for rapid comparison
# will also compare the ecological results from each of them
source(file = file.path(base_path, "Scripts", "ComparingSmoothing.R"))
