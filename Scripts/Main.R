# Main Script -------------------------------------------------------------

base_path <- "C:/Users/oaw001/OneDrive - University of the Sunshine Coast/PostProcessing"
#base_path <- "C:/Users/PC/OneDrive - University of the Sunshine Coast/PostProcessing"

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
       tsfeatures,
       lubridate,
       effsize,
       lme4,
       lmerTest)

# for parallel processing
library(future)
library(future.apply)

# Define variables for this run -------------------------------------------
species <- "Mauny_Goat" # dataset name
target_activity <- "Walk" # behaviour that the ecological analyses will be about

all_species <- c("Dunford_Cat", "Ferdinandy_Dog", "Ladds_Seal", "Maekawa_Gull", "Smit_Cat", "Studd_Squirrel", "Vehkaoja_Dog", "Yu_Duck", "HarveyCaroll_Pangolin", "Mauny_Goat") #, "Sparkes_Koala") 
sample_rates <- list(Dunford_Cat = 40,
                     Ferdinandy_Dog = 100,
                     Ladds_Seal = 25,
                     Maekawa_Gull = 25,
                     Smit_Cat = 30,
                     Sparkes_Koala = 50,
                     Studd_Squirrel = 1,
                     Vehkaoja_Dog = 100,
                     Yu_Duck = 25,
                     HarveyCaroll_Pangolin = 50,
                     Mauny_Goat = 5)

# Dataset Characteristics -------------------------------------------------
# define traits from each of the datasets
source(file = file.path(base_path, "Scripts", "DataFormatting", "DatasetCharacteristics.R"))

# Format Data -------------------------------------------------------------
# collecting the data from various sources and formatting it to standardised structure
available_axes <- c("X", "Y", "Z") 

source(file = file.path(base_path, "Scripts", "DataFormatting", "GenerateFeatures_Functions.R"))
source(file = file.path(base_path, "Scripts", "DataFormatting", paste0(species, "_Formatting.R")))

# Sequential data report --------------------------------------------------
# how natural is this data? # haven't turned this into a markdown yet
source(file = file.path(base_path, "Scripts", "SequentialReport.R"))

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
source(file = file.path(base_path, "Scripts", "Comparisons", "ComparingSmoothing.R"))

# Comparing the comparisons -----------------------------------------------
source(file = file.path(base_path, "Scripts", "Comparisons", "ComparingComparisons.R"))

