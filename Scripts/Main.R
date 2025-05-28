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
source(file = file.path(base_path, "Scripts", "NoSmoothingPerformance.R"))

# Basic Temporal Smoothing ------------------------------------------------
# doing the most basic mode-based smoothing
source(file = file.path(base_path, "Scripts", "BasicSmoothingPerformance.R"))
