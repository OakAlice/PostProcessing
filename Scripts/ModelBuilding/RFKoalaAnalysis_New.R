# Koala Analysis Script v2 ------------------------------------------------
# Updated version of the script for the koala data in Gabby Sparkes' PhD
# Written by Oakleigh Wilson, Nov 2024

# Install packages  -------------------------------------------------------
library(data.table)
library(tidyverse)
library(tsfeatures)
library(umap)
library(caret)
library(ggpubr) # for retrieving the legend in one of my plots
library(randomForest)
library(rBayesianOptimization)
library(ranger)

# Hardcoded variables -----------------------------------------------------
#base_path <- "D:/KoalaAnalysis/AnalysisV2"
base_path <- getwd()
# base_path <- "C:/Users/oaw001/Documents/KoalaAnalysis/AnalysisV2"
sample_rate <- 50
available_axes <- c("Accelerometer.X", "Accelerometer.Y", "Accelerometer.Z", "Gyroscope.X", "Gyroscope.Y", "Gyroscope.Z")
window_length <- 1
overlap_percent <- 50
sig_individuals <- c("Elsa", "Meeka", "Hardy", "Nicole")

# Load and modify data --------------------------------------------------
source(file.path(base_path, "Scripts", "LoadAndTidy_New.R"))

# Split test data out and load other data ---------------------------------
source(file.path(base_path, "Scripts", "SplitTestData_New.R"))

# Visualise behaviours ----------------------------------------------------
# this will save an html report # automation in progress
# source(file.path(base_path, "Scripts", "RenderingMarkdown_New.R"))

# Generate features for training data -------------------------------------
source(file.path(base_path, "Scripts", "GenerateFeatures_New.R"))

# Reclustering the Activities ---------------------------------------------
source(file.path(base_path, "Scripts", "ClusteringActivities_New.R"))

# Hyperparmeter Optimisation ----------------------------------------------
source(file.path(base_path, "Scripts", "HPO_New.R"))
# make the optimal parameters from each HPO round into a csv

# Generate test features --------------------------------------------------
# rerun the same script as for training data but with the test data

# Test optimal models -----------------------------------------------------
source(file.path(base_path, "Scripts", "TestOptimalModels_New.R"))





