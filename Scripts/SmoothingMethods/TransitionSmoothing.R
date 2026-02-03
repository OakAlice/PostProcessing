# Transition Matrix Smoothing ---------------------------------------------

# load in the reaining data
train_data <- fread(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
transition_probabilities <- generate_transition_probabilities(train_data)
transition_probs_melted <- transition_probabilities$transition_probs_melted

# Apply to the test data --------------------------------------------------
if(!file.exists(file.path(base_path, "Output", species, paste0("TransitionSmoothing_performance_", i, ".csv")))){
# I can then use these percentages to assess the validity of the transitions we see in the predictions
## Find all transitions in the predictions data ---------------------------
test_data <- fread(file.path(base_path, "Data", species, paste0("Original_predictions_", i, ".csv"))) %>%
  arrange(ID, Time)
test_data <- identify_sequences(test_data, max_break = ifelse(sample_rates[[species]] > 1, 3, 6)) # based on window duration and buffer

test_data <- find_suspect_transitions(test_data, transition_probs_melted)

# logic of how these are then updated and changed:
# if the transition is unlikely, choose the next most probable class it could have been
# and see whether that one is more likely 
test_data <- update_suspect_transitions(test_data, transition_probs_melted)

## Recalculate performance and save ----------------------------------------
performance <- compute_metrics(as.factor(test_data$smoothed_class), as.factor(test_data$true_class))
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, paste0("TransitionSmoothing_performance_", i, ".csv")))
# generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, paste0("TransitionSmoothing_performance_", i, ".pdf")))

} else {
  print("TransitionSmoothing already calculated")
}
