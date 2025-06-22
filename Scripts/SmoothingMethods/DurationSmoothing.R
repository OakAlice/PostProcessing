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
smooth_durations <- function(data, train_summary){
  
  setDT(data)
  predicted_lengths <- data[, .(
    behaviour = predicted_class[1],
    length = .N
  ), by = .(ID, sequence)]
  
  predicted_lengths <- merge(predicted_lengths, train_summary, by = "behaviour", all.x = TRUE)
  
  predicted_lengths[, acceptable := fcase(
    is.na(p95), "NO MATCHED BEHAVIOUR",
    length > p95, "ACCEPTABLE",
    default = "SUSPICIOUS"
  )]
  
  # Assign smoothed class where acceptable
  predicted_lengths[, smoothed_class := fifelse(acceptable == "ACCEPTABLE", behaviour, NA_character_)]
  
  # Forward-fill suspicious behaviours with previous valid smoothed_class
  predicted_lengths[, smoothed_class := na.locf(smoothed_class, na.rm = FALSE), by = ID]
  
  # Merge smoothed predictions back into test_data
  data <- merge(data, predicted_lengths[, .(ID, sequence, smoothed_class)],
                by = c("ID", "sequence"), all.x = TRUE)
  
  return(data)
}

# Code --------------------------------------------------------------------
## Load in the training data
train_data <- fread(file.path(base_path, "Data", "StandardisedPredictions", paste0(species, "_raw_train_standardised.csv")))

## Identify sequences of continuous behaviour
train_data <- identify_sequences(train_data, "true_class")

## Learn from the training data
setDT(train_data)
train_lengths <- train_data[, .(
  behaviour = true_class[1],
  length = .N
), by = .(ID, sequence)]

train_summary <- train_lengths[length > 1, .(p95 = quantile(length, 0.05)), by = behaviour]

## Use this to logic-gate the smoothing 
test_data <- fread(file.path(base_path, "Data", "StandardisedPredictions", paste0(species, "_test_data.csv")))
test_data <- identify_sequences(test_data, "predicted_class")

## Check whether each instance is likely legit based on its duration
test_data <- smooth_durations(test_data, train_summary)

# Recalculate performance and save
performance <- compute_metrics(test_data$smoothed_class, test_data$true_class)
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, "DurationSmoothing_performance.csv"))
generate_confusion_plot(performance$conf_matrix_padded,
                        save_path = file.path(base_path, "Output", species, "DurationSmoothing_performance.pdf"))

# Calculate ecological results --------------------------------------------
ecological_data <- fread(file.path(base_path, "Data", "UnlabelledData", paste0(species, "_unlabelled_predicted.csv")))

# Apply the smoothing
ecological_data <- identify_sequences(ecological_data, "predicted_class")
ecological_data <- smooth_durations(ecological_data, train_summary)

# Calculate what this means
eco <- ecological_analyses(smoothing_type = "Duration", 
                           eco_data = ecological_data, 
                           target_activity = target_activity)

question1 <- eco$sequence_summary
question2 <- eco$hour_proportions

# Write outputs
fwrite(question1, file.path(base_path, "Output", species, "DurationSmoothing_eco1.csv"))
fwrite(question2, file.path(base_path, "Output", species, "DurationSmoothing_eco2.csv"))
