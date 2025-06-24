# Basic Smoothing ---------------------------------------------------------
# a very simple rolling mode 

# Functions ---------------------------------------------------------------
# finding the mode, where x is user defined (so they can change it based on eco context)
rolling_mode_smooth <- function(column, x = 5) {
  stopifnot(x %% 2 == 1)  # ensure odd window size
  half_window <- floor(x / 2)
  result <- column  # initialize output
  
  for (i in (half_window + 1):(length(column) - half_window)) {
    window <- column[(i - half_window):(i + half_window)]
    mode_val <- names(sort(table(window), decreasing = TRUE))[1]
    result[i] <- mode_val
  }
  
  return(result)
}

# Code --------------------------------------------------------------------
x <- 5 # window size for smoothing

# load in the raw data again
data <- fread(file.path(base_path, "Data", species, "Original_predictions.csv"))

# in order to create a 'smoothed' class, I am going to do a rolling mode that removes lone instances
data$smoothed_class <- rolling_mode_smooth(data$predicted_class, x = x)

# and now recalculate the performance
performance <- compute_metrics(as.factor(data$smoothed_class), as.factor(data$true_class))
metrics <- performance$metrics

# save these
fwrite(metrics, file.path(base_path, "Output", species, "ModeSmoothing_performance.csv"))
generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, "ModeSmoothing_performance.pdf"))


# Calculate ecological results --------------------------------------------
if (file.exists(file.path(base_path, "Data", species, "Unlabelled_predictions.csv"))){
    
  ecological_data <- fread(file.path(base_path, "Data", species, "Unlabelled_predictions.csv")))
  
  # apply the smoothing
  ecological_data$smoothed_class <- rolling_mode_smooth(ecological_data$predicted_class, x = x)
  
  # calculate what this means
  eco <- ecological_analyses(smoothing_type = "Mode", 
                             eco_data = ecological_data, 
                             target_activity = target_activity)
  question1 <- eco$sequence_summary
  question2 <- eco$hour_proportions
  
  # write these to files
  fwrite(question1, file.path(base_path, "Output", species, "ModeSmoothing_eco1.csv"))
  fwrite(question2, file.path(base_path, "Output", species, "ModeSmoothing_eco2.csv"))
} else {
  print("there is no ecological data for this dataset")
}
