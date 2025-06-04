# Basic Smoothing ---------------------------------------------------------
# a very simple rolling mode 

# load in the raw data again
data <- fread(file.path(base_path, "Data", "StandardisedFormat", paste0(species, "_test_data.csv")))

# in order to create a 'smoothed' class, I am going to do a rolling mode that removes lone instances
data$smoothed_class <- rolling_mode_smooth(data$predicted_class, x = 5)

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
