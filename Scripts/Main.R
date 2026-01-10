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
       tsfeatures,
       lubridate,
       effsize,
       lme4,
       lmerTest)

# for parallel processing
library(future)
library(future.apply)

# Define variables for this run -------------------------------------------
species <- "Galea_Cat" # dataset name
target_activity <- "Walk" # behaviour that the ecological analyses will be about
overlap <- 0 # same for every dataset
hours_since_creation <- 5 # overwrite model and post-processing files if they were done more than X hrs ago

all_species <- c( "Dunford_Cat", "Ferdinandy_Dog", "Ladds_Seal", 
                  "Maekawa_Gull", "Smit_Cat", "Yu_Duck", "Vehkaoja_Dog", # "Studd_Squirrel",
                  "HarveyCaroll_Pangolin", "Mauny_Goat", "Clemente_Echidna", "Galea_Cat", "Sparkes_Koala") 
sample_rates <- list(Galea_Cat = 50,
                     Pagano_Bear = 16,
                     Dunford_Cat = 40,
                     Ferdinandy_Dog = 100,
                     Ladds_Seal = 25,
                     Maekawa_Gull = 25,
                     Smit_Cat = 30,
                     Sparkes_Koala = 50,
                     Studd_Squirrel = 1,
                     Vehkaoja_Dog = 100,
                     Yu_Duck = 25,
                     HarveyCaroll_Pangolin = 50,
                     Mauny_Goat = 5,
                     Clemente_Echidna = 10)


# Functions ---------------------------------------------------------------
source(file = file.path(base_path, "Scripts", "DataFormatting", "GenerateFeatures_Functions.R"))
source(file = file.path(base_path, "Scripts", "PerformanceTestingFunctions.R"))
source(file = file.path(base_path, "Scripts", "EcologicalTestingFunctions.R"))
source(file = file.path(base_path, "Scripts", "PlottingFunctions.R"))

# Dataset Characteristics -------------------------------------------------
# define traits from each of the datasets
# source(file = file.path(base_path, "Scripts", "DataFormatting", "DatasetCharacteristics.R"))

# Format Data -------------------------------------------------------------
# collecting the data from various sources and formatting it to standardised structure

run_species <- all_species# [5:length(all_species)]
for (species in run_species){ # TODO: remove this
available_axes <- c("X", "Y", "Z") 

print(species)

source(file = file.path(base_path, "Scripts", "DataFormatting", paste0(species, "_Formatting.R")))
source(file = file.path(base_path, "Scripts", "DataFormatting", "GenerateFeatures.R"))

# Sequential data report --------------------------------------------------
# how natural is this data? # haven't turned this into a markdown yet
# source(file = file.path(base_path, "Scripts", "SequentialReport.R"))

# Make the Model ----------------------------------------------------------
# tune, train, and test a model and generate predictions on the test data
source(file = file.path(base_path, "Scripts", "ModelBuilding", "BuildModel.R"))

# Compare the smoothing options -------------------------------------------
# Make the directory ------------------------------------------------------
if (!dir.exists(file.path(base_path, "Output", species))){
  dir.create(file.path(base_path, "Output", species))
}

# No Smoothing ------------------------------------------------------------
# assess performance and base stats of the raw predictions
source(file = file.path(base_path, "Scripts", "SmoothingMethods", "NoSmoothing.R"))

# Basic Temporal Smoothing ------------------------------------------------
# doing the most basic mode-based smoothing
source(file = file.path(base_path, "Scripts", "SmoothingMethods", "ModeSmoothing.R"))

# Duration Smoothing ------------------------------------------------------
# removing too-short instances based on the 95th percentile durations
source(file = file.path(base_path, "Scripts", "SmoothingMethods", "DurationSmoothing.R"))

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
# TODO: reinstate this
# source(file = file.path(base_path, "Scripts", "SmoothingMethods", "LSTMSmoothing.R"))

} # TODO: remove this

# Comparing Smoothing Performances ----------------------------------------
# this will pull out all the metrics tests and build a report for rapid comparison
# will also compare the ecological results from each of them
source(file = file.path(base_path, "Scripts", "Comparisons", "ComparingSmoothing.R"))

# Comparing the comparisons -----------------------------------------------
source(file = file.path(base_path, "Scripts", "Comparisons", "ComparingComparisons.R"))

