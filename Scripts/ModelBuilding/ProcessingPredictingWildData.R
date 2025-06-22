
# Processing Raw Wild Data ------------------------------------------------
# generate features and generate predictions



# Set up and packages -----------------------------------------------------
library(data.table)
library(tidyverse)
library(tsfeatures)
library(caret)
library(randomForest)
library(ranger)
library(future.apply)
library(purrr)
library(tibble)

BASE_PATH <- "C:/Users/PC/OneDrive - University of the Sunshine Coast/KoalaProject"

# parameters
sample_rate <- 50
available_axes <- c("Accelerometer.X", "Accelerometer.Y", "Accelerometer.Z", "Gyroscope.X", "Gyroscope.Y", "Gyroscope.Z")
window_length <- 1
overlap_percent <- 0

# load in the previously trained model
model_path <- file.path(BASE_PATH, "AnalysisV2", "Output", "GeneralisedActivity_model.rds")
RF_model <- readRDS(model_path)

# extract the features
selected_features <- RF_model[["forest"]][["independent.variable.names"]]

# Load in and process all the files ---------------------------------------
koala_folders <- list.dirs(file.path(BASE_PATH, "Raw_Wild_Data"), recursive = FALSE)

# Plan for parallel execution (adjust based on system resources)
process_file <- function(file, ID, processed_folder_path, predicted_folder_path) {
  start_time <- Sys.time()
  file_name <- sub("\\.csv$", "", basename(file))
  cat(sprintf("\n[%s] Processing: %s\n", format(start_time, "%H:%M:%S"), file_name))
  
  tryCatch({
    processed_file_path <- file.path(processed_folder_path, paste0(file_name, "_features.csv"))
    predicted_file_path <- file.path(predicted_folder_path, paste0(file_name, "_predictions.csv"))
    
    # Feature generation step
    if (!file.exists(processed_file_path)) {
      raw_data <- fread(file, colClasses = c("NULL", rep("numeric", 7)))  # Skip "Row" column
      setnames(raw_data, c("Time", "Accelerometer.X", "Accelerometer.Y", "Accelerometer.Z", 
                           "Gyroscope.X", "Gyroscope.Y", "Gyroscope.Z"))
      raw_data[, ID := ID]
      
      message(sprintf("[%s] Generating features...", format(Sys.time(), "%H:%M:%S")))
      feature_data <- generateSpecificFeatures(window_length, 
                                               sample_rate, 
                                               overlap_percent, 
                                               raw_data, 
                                               specific_features = selected_features)
        
      fwrite(feature_data, processed_file_path)
    } else {
      feature_data <- fread(processed_file_path)
    }
    
    # Prediction step
    if (!file.exists(predicted_file_path)) {
      message(sprintf("[%s] Running predictions...", format(Sys.time(), "%H:%M:%S")))
      
      bonus_feature_data <- feature_data[, .(Time, maxVDBA, minVDBA)]
      clean_feature_data <- na.omit(feature_data[, c(selected_features, "Time", "ID"), with = FALSE])
      metadata <- clean_feature_data[, .(Time, ID)]
      
      numeric_data <- as.matrix(clean_feature_data[, !c("ID", "Time"), with = FALSE])
      predictions <- predict(RF_model, data = numeric_data)$predictions
      predictions_df <- cbind(predicted_classes = factor(predictions), metadata)
      predictions_df <- merge(predictions_df, bonus_feature_data, by = "Time")
      
      fwrite(predictions_df, predicted_file_path)
      message("Predictions saved.")
    } else {
      message(sprintf("[%s] Predictions already exist", format(Sys.time(), "%H:%M:%S")))
    }
    
    end_time <- Sys.time()
    elapsed <- difftime(end_time, start_time, units = "secs")
    cat(sprintf("[%s] Completed %s: %.1f sec (%.1f min)\n", 
                format(end_time, "%H:%M:%S"), file_name, as.numeric(elapsed), as.numeric(elapsed)/60))
    
    gc()  # Force garbage collection
    return(TRUE)
  }, error = function(e) {
    end_time <- Sys.time()
    elapsed <- difftime(end_time, start_time, units = "secs")
    cat(sprintf("[%s] ERROR processing %s (%.1f sec): %s\n", 
                format(end_time, "%H:%M:%S"), file_name, as.numeric(elapsed), e$message))
    return(FALSE)
  })
}

# Process all folders one by one
for (folder in koala_folders){
  # folder <- koala_folders[1]
  ID <- sub(".*/([^/]+)_Chunked$", "\\1", folder)
  
  processed_folder_path <- file.path(BASE_PATH, "Processed_Wild_Data", ID)
  if (!dir.exists(processed_folder_path)) dir.create(processed_folder_path, recursive = TRUE)
  
  predicted_folder_path <- file.path(BASE_PATH, "Predicted_Wild_Data", ID)
  if (!dir.exists(predicted_folder_path)) dir.create(predicted_folder_path, recursive = TRUE)
  
  chunked_files <- list.files(folder, pattern = "*.csv", full.names = TRUE)
  
  # Process files in parallel within each folder
  results <- map(chunked_files, ~ process_file(.x, ID, processed_folder_path, predicted_folder_path))
}

plan(sequential())