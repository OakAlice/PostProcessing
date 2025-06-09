# Basic Smoothing ---------------------------------------------------------
# a very simple rolling mode 

x <- 5 # window size for smoothing

# load in the raw data again
data <- fread(file.path(base_path, "Data", "StandardisedFormat", paste0(species, "_test_data.csv")))

# in order to create a 'smoothed' class, I am going to do a rolling mode that removes lone instances
data$smoothed_class <- rolling_mode_smooth(data$predicted_class, x = x)

# and now recalculate the performance
performance <- compute_metrics(data$smoothed_class, data$true_class)
metrics <- performance$metrics

# save these
fwrite(metrics, file.path(base_path, "Output", species, "BasicSmoothing_performance.csv"))
generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, "BasicSmoothing_performance.pdf"))

# Functions for the smoothing ---------------------------------------------
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

# Calculate ecological results --------------------------------------------
ecological_data <- fread(file.path(base_path, "Data", "UnlabelledData", paste0(species, "_unlabelled_predicted.csv")))

# apply the smoothing
ecological_data$smoothed_class <- rolling_mode_smooth(ecological_data$predicted_class, x = x)

# calculate what this means
eco <- ecological_analyses(smoothing_type = "None", 
                           test_data = ecological_data, 
                           target_activity = target_activity)
question1 <- eco$sequence_summary
question2 <- eco$hour_proportions

# write these to files
fwrite(question1, file.path(base_path, "Output", species, "ModeSmoothing_eco1.csv"))
fwrite(question2, file.path(base_path, "Output", species, "ModeSmoothing_eco2.csv"))
