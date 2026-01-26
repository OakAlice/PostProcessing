# Duration based smoothing ------------------------------------------------
# This is where we use information about durations of behaviours in the training set
# to devise logical smoothing brackets for the predictions

# Functions ---------------------------------------------------------------
# find the sequences in specified column
identify_sequences <- function(data, class_col = "true_class") {
  class_sym <- sym(class_col)
  
  data <- data %>%
    arrange(ID, Time) %>%
    group_by(ID) %>%
    mutate(
      change_point = if_else(lag(!!class_sym) == !!class_sym, 0L, 1L),
      change_point = replace_na(change_point, 0L),
      sequence = cumsum(change_point)
    ) %>%
    ungroup()
  
  return(data)
}

# smooth
smooth_durations <- function(data, train_summary, min_rule) {

  setDT(data)
  setDT(train_summary)
  
  # Extract predicted bout lengths
  predicted_lengths <- data[, .(
    behaviour = as.character(predicted_class[1]),
    length = .N
  ), by = .(ID, sequence)]
  
  # Join training duration stats
  predicted_lengths <- merge(
    predicted_lengths,
    train_summary,
    by = "behaviour",
    all.x = TRUE
  )
  
  # flag the ones with issues
  predicted_lengths[, status := "OK"]
  predicted_lengths[is.na(min_len), status := "NO_MATCH"]
  predicted_lengths[length < min_len, status := "TOO_SHORT"]
  predicted_lengths[length > p95,     status := "TOO_LONG"]

  # Initialise smoothed class
  predicted_lengths[, smoothed_class := behaviour]
  predicted_lengths[status == "TOO_SHORT", smoothed_class := NA_character_]
  
  # Merge short bouts to nearest valid neighbour (within ID)
  predicted_lengths[, smoothed_class :=
                      zoo::na.locf(smoothed_class, na.rm = FALSE), by = ID]
  predicted_lengths[, smoothed_class :=
                      zoo::na.locf(smoothed_class, fromLast = TRUE, na.rm = FALSE), by = ID]
  
  # Merge back to original data
  data <- merge(
    data,
    predicted_lengths[, .(ID, sequence, smoothed_class, status)],
    by = c("ID", "sequence"),
    all.x = TRUE
  )
  
  return(data)
}


# Code --------------------------------------------------------------------
## Load in the training data
train_data <- fread(file.path(base_path, "Data", species, "Formatted_raw_data.csv")) %>%
  rename(true_class = Activity)

## Identify sequences of continuous behaviour
train_data <- identify_sequences(train_data, "true_class")

## Learn from the training data
setDT(train_data)
train_lengths <- train_data[, .(
  behaviour = as.character(true_class[1]),
  length = .N
), by = .(ID, sequence)]

# make a distribution of the behaviours
# ggplot(train_lengths, aes(x = length, fill = behaviour)) +
#   geom_histogram()

# finding rhe mode as well
stat_mode <- function(x) {
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}

# its in raw samples at the moment so need to summarise to seconds
train_summary <- train_lengths %>%
  group_by(behaviour) %>%
  summarise(
    min_len= min(length)/sample_rate,
    mean   = mean(length)/sample_rate,
    median = median(length)/sample_rate,
    mode   = stat_mode(length)/sample_rate,
    p75    = quantile(length, 0.75)/sample_rate,
    p95    = quantile(length, 0.95)/sample_rate,
    max    = max(length),
    .groups = "drop"
  )

## Use this to logic-gate the smoothing 
test_data <- fread(file.path(base_path, "Data", species, paste0("Original_predictions_", i, ".csv")))
test_data <- identify_sequences(test_data, "predicted_class")

## Check whether each instance is likely legit based on its duration
test_data <- smooth_durations(test_data, train_summary, min_rule = "p75")

# Recalculate performance and save
performance <- compute_metrics(as.factor(test_data$smoothed_class), as.factor(test_data$true_class))
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, paste0("DurationSmoothing_performance_", i, ".csv")))
#generate_confusion_plot(performance$conf_matrix_padded,
#                        save_path = file.path(base_path, "Output", species, paste0("DurationSmoothing_performance_", i, ".pdf")))

