# Main Script -------------------------------------------------------------

base_path <- "C:/Users/oaw001/OneDrive - University of the Sunshine Coast/PostProcessing"

#install.packaged("pacman")
library(pacman)

p_load(tidyverse, 
       data.table,
       caret,
       ggplot2,
       HMM,
       torch)


# Define variables for this run -------------------------------------------
species <- "Sparkes_Koala" # dataset name
target_activity <- "Walking" # behaviour that the ecological analyses will be about

# Standardise format ------------------------------------------------------
# data must be saved in Data/Species folders with c(Time, ID, true_classes, generalised_classes, predicted_classes) columns
# source(file = file.path(base_path, "Scripts", "DataFormatStandardisation.R"))


# Important functions -----------------------------------------------------
source(file = file.path(base_path, "Scripts", "PerformanceTestingFunctions.R"))
source(file = file.path(base_path, "Scripts", "EcologicalTestingFunctions.R"))
source(file = file.path(base_path, "Scripts", "PlottingFunctions.R"))

# No Smoothing ------------------------------------------------------------
# assess performance and base stats of the raw predictions
source(file = file.path(base_path, "Scripts", "NoSmoothing.R"))

# Basic Temporal Smoothing ------------------------------------------------
# doing the most basic mode-based smoothing
source(file = file.path(base_path, "Scripts", "ModeSmoothing.R"))

# Duration Smoothing ------------------------------------------------------
# removing too-short instances based on the 95th percentile durations
source(file = file.path(base_path, "Scripts", "DurationSmoothing.R"))

# Confusion Smoothing -----------------------------------------------------
# correcting for flaws in the prediction system
source(file = file.path(base_path, "Scripts", "ConfusionSmoothing.R"))

# Transition Smoothing ----------------------------------------------------
# removing improbable behavioural transitions
source(file = file.path(base_path, "Scripts", "TransitionSmoothing.R"))

# HMM Smoothing -----------------------------------------------------------
# using secondary Hidden Markov Model to smooth 
source(file = file.path(base_path, "Scripts", "HMMSmoothing.R"))

# Bayesian Smoothing ------------------------------------------------------
# Bayes rules to smooth transitions
source(file = file.path(base_path, "Scripts", "BayesianSmoothing.R"))

# LSTM Smoothing ----------------------------------------------------------
# warning - difficult packages - do this one manually
LSTMSmoothing_file <- file.path(base_path, "Scripts", "LSTMSmoothing.R")



# Comparing Smoothing Performances ----------------------------------------
# this will pull out all the metrics tests and build a report for rapid comparison
# will also compare the ecological results from each of them
source(file = file.path(base_path, "Scripts", "CompareSmoothing.R"))
