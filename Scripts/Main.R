# Main Script -------------------------------------------------------------

base_path <- "C:/Users/oaw001/OneDrive - University of the Sunshine Coast/PostProcessing"

#install.packaged("pacman")
library(pacman)

p_load(tidyverse, 
       data.table,
       caret,
       ggplot2)


# Define variables for this run -------------------------------------------
species <- "Sparkes_Koala"

# Standardise format ------------------------------------------------------
# data must be saved in Data/Species folders with c(Time, ID, true_classes, generalised_classes, predicted_classes) columns
source(file = file.path(base_path, "Scripts", "DataFormatStandardisation.R"))

# No Smoothing ------------------------------------------------------------
# assess performance and base stats of the raw predictions
source(file = file.path(base_path, "Scripts", "NoSmoothing.R"))

# Basic Temporal Smoothing ------------------------------------------------
# doing the most basic mode-based smoothing
source(file = file.path(base_path, "Scripts", "BasicSmoothing.R"))

# Duration Smoothing ------------------------------------------------------
# removing too-short instances based on the 95th percentile durations
source(file = file.path(base_path, "Scripts", "DurationSmoothing.R"))

# Confusion Smoothing -----------------------------------------------------
# correcting for flaws in the prediction system
source(file = file.path(base_path, "Scripts", "ConfusionSmoothing.R"))




# Comparing Smoothing Performances ----------------------------------------
# this will pull out all the metrics tests and build a report for rapid comparison
source(file = file.path(base_path, "Scripts", "CompareSmoothing.R"))
