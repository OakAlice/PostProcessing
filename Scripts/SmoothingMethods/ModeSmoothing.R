# Basic Smoothing ---------------------------------------------------------
# a very simple rolling mode 

# Functions ---------------------------------------------------------------
# finding the mode, where x is user defined (so they can change it based on eco context)
rolling_mode_smooth <- function(data, x = 5) {
  stopifnot(x %% 2 == 1)  # ensure odd window
  half_window <- floor(x / 2)
  
  data %>%
    group_by(sequence) %>%
    mutate(
      smoothed_class = {
        v <- predicted_class
        out <- v
        
        if (length(v) < x) {
          # short sequence: replace all by mode
          out <- names(sort(table(v), decreasing = TRUE))[1]
        } else {
          # longer sequence: standard rolling mode
          for (i in (half_window + 1):(length(v) - half_window)) {
            window <- v[(i - half_window):(i + half_window)]
            out[i] <- names(sort(table(window), decreasing = TRUE))[1]
          }
        }
        
        out
      }
    ) %>%
    ungroup()
}

# Code --------------------------------------------------------------------
if(!file.exists(file.path(base_path, "Output", species, paste0("ModeSmoothing_performance_", i, ".csv")))){

# load in the raw data again
data <- fread(file.path(base_path, "Data", species, paste0("Original_predictions_", i, ".csv")))

# find the continuous sequences of data
data <- identify_sequences(data, max_break = ifelse(sample_rates[[species]] > 1, 2.5, 5.5)) # looking at the window breaks but with a little safety buffer

# in order to create a 'smoothed' class, I am going to do a rolling mode that removes lone instances
data <- rolling_mode_smooth(data, x = 5)

# and now recalculate the performance
performance <- compute_metrics(as.factor(data$smoothed_class), as.factor(data$true_class))
metrics <- performance$metrics

# save these
fwrite(metrics, file.path(base_path, "Output", species, paste0("ModeSmoothing_performance_", i, ".csv")))
#generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, paste0("ModeSmoothing_performance_", i, ".pdf")))

} else {
  print("ModeSmoothing already calculated")
}