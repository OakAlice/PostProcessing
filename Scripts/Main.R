# Main Script -------------------------------------------------------------

base_path <- "C:/Users/oaw001/OneDrive - University of the Sunshine Coast/PostProcessing"
# base_path <- "C:/Users/PC/OneDrive - University of the Sunshine Coast/PostProcessing"

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
       lmerTest,
       rBayesianOptimization,
       ranger)

# for parallel processing
library(future)
library(future.apply)

# Define variables for this run -------------------------------------------
overlap <- 0 # same for every dataset
hours_since_creation <- 20 # overwrite model and post-processing files if they were done more than X hrs ago
available_axes <- c("X", "Y", "Z") # annopying variable I haven't gotten rid of yet

all_species <- list.dirs(file.path(base_path, "Data"), recursive = FALSE)
sample_rates <- list(Galea_Cat = 50,
                     Dunford_Cat = 40,
                     Ferdinandy_Dog = 100,
                     Ladds_Seal = 25,
                     Maekawa_Gull = 25,
                     Smit_Cat = 30,
                     Studd_Squirrel = 1,
                     Desantis_Rattlesnake = 1, 
                     Vehkaoja_Dog = 100,
                     Yu_Duck = 25,
                     HarveyCaroll_Pangolin = 50,
                     Pagano_Bear = 16,
                     Sparkes_Koala = 50,
                     Mauny_Goat = 5,
                     Clemente_Echidna = 10
                     )

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

for (species in all_species){ 
 
  print(species)
  species <- basename(species)
  
  source(file = file.path(base_path, "Scripts", "DataFormatting", paste0(species, "_Formatting.R")))
  source(file = file.path(base_path, "Scripts", "DataFormatting", "GenerateFeatures.R"))
  
  # Sequential data report --------------------------------------------------
  # how natural is this data? # haven't turned this into a markdown yet
  # source(file = file.path(base_path, "Scripts", "SequentialReport.R"))
  
  # repeat the entire process 3 times for cross-validation
  # assign IDs to their fold
  data <- fread(file.path(base_path, "Data", species, "Feature_data.csv"))
  unique_IDs <- unique(data$ID)
  ID_groups <- data.frame(
   ID = unique_IDs,
   group = sample(rep(1:3, length.out = length(unique_IDs)))
  )

  for (i in 1:3){
   print(i)
   # define the test IDs for this round
   test_IDs <- ID_groups$ID[ID_groups$group == i]
  
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
   source(file = file.path(base_path, "Scripts", "SmoothingMethods", "LSTMSmoothing.R"))
  
  }

  
  # Comparing Smoothing Performances ----------------------------------------
  # this will pull out all the metrics tests and build a report for rapid comparison
  # will also compare the ecological results from each of them
  
  
  source(file = file.path(base_path, "Scripts", "Comparisons", "ComparingSmoothing.R"))

}

# Comparing the comparisons -----------------------------------------------
source(file = file.path(base_path, "Scripts", "Comparisons", "ComparingComparisons.R"))

