# Duration based smoothing ------------------------------------------------
# this is where we use information about duratios of behaviours in the training set
# to devise logical smoothing brackets for the predictions

# load in the training data
train_data <- fread(file.path(base_path, "Data", "StandardisedFormat", paste0(species, "_raw_train_standardised.csv")))

# Identify sequences of continuous behaviour ------------------------------
# number the consecutive sequences
train_data <- train_data %>%
  arrange(ID, Time) %>%
  group_by(ID) %>%
  mutate(
    change_point = ifelse(shift(true_class, type = "lag") == true_class, 0, 1),
    change_point = replace_na(change_point, 0),
    sequence = cumsum(change_point)
  ) %>%
  ungroup()

# Learn from the training data --------------------------------------------
train_lengths <- train_data %>% 
  group_by(ID, sequence) %>%
  summarise(behaviour = true_class[1], length = length(sequence))
train_summary <- train_lengths %>%
  group_by(behaviour) %>%
  # remove all the 1 second instances (they just dominate the frequency completely)
  filter(!length == 1) %>%
  summarise(mean = round(mean(length),1), max = max(length), min = min(length), p95 = quantile(length, 0.05))

# Use this to logic gate the smoothing ------------------------------------
# now we switch to fixing the test data
test_data <- fread(file.path(base_path, "Data", "StandardisedFormat", paste0(species, "_raw_test_standardised.csv")))

# begin by figuring out the sequence in the predictions
predicted_data <- test_data %>%
  arrange(ID, Time) %>%
  group_by(ID) %>%
  mutate(
    change_point = ifelse(shift(predicted_class, type = "lag") == predicted_class, 0, 1),
    change_point = replace_na(change_point, 0),
    sequence = cumsum(change_point)
  ) %>%
  ungroup()

# go through and check whether each instance is likely legit or not
# this is based on whether its longer than the p95
predicted_lengths <- predicted_data %>% 
  group_by(ID, sequence) %>%
  summarise(behaviour = predicted_class[1], length = length(sequence), .groups = "drop") %>%
  left_join(train_summary, by = "behaviour") %>%
  mutate(
    acceptable = case_when(
      is.na(p95) ~ "NO MATCHED BEHAVIOUR",
      length > p95 ~ "ACCEPTABLE",
      TRUE ~ "SUSPICIOUS"
    )
  )

# change the probably illegitimate ones to something else
# if they are too short, set them to the acceotable behaviour that preceeded it
# if too long, leave for now... I need to think about this more.
predictions_altered <- predicted_lengths %>%
    mutate(smoothed_class = ifelse(acceptable == "ACCEPTABLE", behaviour, NA)
  ) %>%
  group_by(ID) %>% 
  fill(smoothed_class, .direction = "down") %>%
  select(ID, sequence, smoothed_class) %>%
  ungroup()

# add this back into the original dataframe
test_data <- left_join(predicted_data, predictions_altered, by = c('ID', 'sequence'))

# fwrite(test_data, file.path(base_path, "Output", species, "checking_data.csv"))

# Recalculate performance and save ----------------------------------------
performance <- compute_metrics(test_data$smoothed_class, test_data$true_class)
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, "DurationSmoothing_performance.csv"))
generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, "DurationSmoothing_performance.pdf"))
