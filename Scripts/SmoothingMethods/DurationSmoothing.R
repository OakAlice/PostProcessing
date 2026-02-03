# Duration based smoothing ------------------------------------------------
# This is where we use information about durations of behaviours in the training set
# to devise logical smoothing brackets for the predictions

if(!file.exists(file.path(base_path, "Output", species, paste0("DurationSmoothing_performance_", i, ".csv")))){
  
## Load in the training data
train_data <- fread(file.path(base_path, "Data", species, "Formatted_raw_data.csv")) %>%
  rename(true_class = Activity) %>%
  arrange(ID, Time)

## Identify sequences of continuous sampling and continuous behaviours
train_data <- identify_sequences(train_data, max_break = ifelse(sample_rates[[species]] > 1, 2.5, 5.5)) # based on window duration and buffer
train_data <- identify_events(train_data, class_col = "true_class")

duration_information <- generate_duration_summaries(train_data)

## Use this to logic-gate the smoothing 
test_data <- fread(file.path(base_path, "Data", species, paste0("Original_predictions_", i, ".csv")))
test_data <- identify_sequences(test_data, max_break = ifelse(sample_rates[[species]] > 1, 2.5, 5.5)) # looking at the window breaks but with a little safety buffer
test_data <- identify_events(test_data, "predicted_class")

## Check whether each instance is likely legit based on its duration
test_data <- smooth_durations(test_data, 
                              duration_information$train_summary, 
                              duration_information$minumum_considered_seq_length, 
                              min_rule = "p75")

# Recalculate performance and save
performance <- compute_metrics(as.factor(test_data$smoothed_class), as.factor(test_data$true_class))
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, paste0("DurationSmoothing_performance_", i, ".csv")))
#generate_confusion_plot(performance$conf_matrix_padded,
#                        save_path = file.path(base_path, "Output", species, paste0("DurationSmoothing_performance_", i, ".pdf")))

} else {
  print("DurationSmoothing already calculated")
}