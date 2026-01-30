# Duration based smoothing ------------------------------------------------
# This is where we use information about durations of behaviours in the training set
# to devise logical smoothing brackets for the predictions

# Functions ---------------------------------------------------------------
# smooth
smooth_durations <- function(test_data, train_summary, minumum_considered_seq_length, min_rule) {

  setDT(test_data)
  setDT(train_summary)
  
  predicted_lengths <- test_data %>%
    group_by(ID, sequence) %>%
    mutate(sequence_length = n()) %>%
    group_by(ID, sequence, event) %>%
    summarise(
      behaviour = first(predicted_class),
      event_length = n(),
      sequence_length = first(sequence_length),
      .groups = "drop"
    ) %>%
    mutate(behaviour = as.character(behaviour))
  
  # flag the ones with issues
  # issues are: the sequence itself is too short
  # the event is the entire duration of the sequence (i.e., we dont have information about true length)
  # the event (inside of a longer sequence) is too short
  predicted_lengths <- predicted_lengths %>%
    left_join(
      train_summary %>% select(behaviour, !!min_rule),
      by = "behaviour"
    ) %>%
    mutate(
      status = case_when(
        sequence_length < minumum_considered_seq_length ~
          "It is what it is",
        
        event_length == sequence_length ~
          "event is the whole sequence, not enough info",
        
        event_length < .data[[min_rule]] ~
          "too short",
        
        TRUE ~ "good"
      )
    )
  
  # Change all the ones that are too short into the most common behaviour in the sequence
  predicted_lengths <- predicted_lengths %>%
    group_by(ID, sequence) %>%
    mutate(
      mode_behaviour = behaviour[which.max(table(behaviour))],
      smoothed_class = if_else(
        status == "too short",
        mode_behaviour,
        behaviour
      )
    ) %>%
    ungroup()
  
  # Merge back to original data
  test_data <- test_data %>%
    left_join(
      predicted_lengths %>%
        select(ID, sequence, event, smoothed_class, status),
      by = c("ID", "sequence", "event")
    )
  
  
  return(test_data)
}


# Code --------------------------------------------------------------------
if(!file.exists(file.path(base_path, "Output", species, paste0("DurationSmoothing_performance_", i, ".csv")))){
  
## Load in the training data
train_data <- fread(file.path(base_path, "Data", species, "Formatted_raw_data.csv")) %>%
  rename(true_class = Activity) %>%
  arrange(ID, Time)

## Identify sequences of continuous sampling and continuous behaviours
train_data <- identify_sequences(train_data, max_break = ifelse(sample_rates[[species]] > 1, 2.5, 5.5)) # based on window duration and buffer
train_data <- identify_events(train_data, class_col = "true_class")

# Learn from the training data # these are the lengths in raw samples
setDT(train_data)
train_lengths <- train_data[, .(
  behaviour = as.character(true_class[1]),
  length = .N
), by = .(ID, sequence, event)]

sequence_lengths <- train_data[, .(
  behaviour = as.character(true_class[1]),
  length = .N
), by = .(ID, sequence)] 
minumum_considered_seq_length <- min(sequence_lengths$length)

# make a distribution of the behaviours
# ggplot(train_lengths, aes(x = length, fill = behaviour)) +
#   geom_histogram()

# finding rhe mode as well
stat_mode <- function(x) {
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}

# its in raw samples at the moment so need to summarise to windows
window_samples <- sample_rates[[species]] * ifelse(sample_rates[[species]] > 1, 2, 5)
train_summary <- train_lengths %>%
  group_by(behaviour) %>%
  summarise(
    min_len= ceiling(min(length)/window_samples),
    mean   = ceiling(mean(length)/window_samples),
    median = ceiling(median(length)/window_samples),
    mode   = ceiling(stat_mode(length)/window_samples),
    p75    = ceiling(quantile(length, 0.25)/window_samples), # longer than 75% of examples
    p95    = ceiling(quantile(length, 0.05)/window_samples), # longer than 95% of examples
    max    = ceiling(max(length)),
    .groups = "drop"
  ) %>% # note that this is measured in windows
  mutate(behaviour = as.character(behaviour))

## Use this to logic-gate the smoothing 
test_data <- fread(file.path(base_path, "Data", species, paste0("Original_predictions_", i, ".csv")))
test_data <- identify_sequences(test_data, max_break = ifelse(sample_rates[[species]] > 1, 2.5, 5.5)) # looking at the window breaks but with a little safety buffer
test_data <- identify_events(test_data, "predicted_class")

## Check whether each instance is likely legit based on its duration
test_data <- smooth_durations(test_data, train_summary, minumum_considered_seq_length, min_rule = "p75")

# Recalculate performance and save
performance <- compute_metrics(as.factor(test_data$smoothed_class), as.factor(test_data$true_class))
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, paste0("DurationSmoothing_performance_", i, ".csv")))
#generate_confusion_plot(performance$conf_matrix_padded,
#                        save_path = file.path(base_path, "Output", species, paste0("DurationSmoothing_performance_", i, ".pdf")))

} else {
  print("DurationSmoothing already calculated")
}