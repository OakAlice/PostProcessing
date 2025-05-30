# Duration based smoothing ------------------------------------------------
# this is where we use information about duratios of behaviours in the training set
# to devise logical smoothing brackets for the predictions

# load in the raw data again
data <- fread(file.path(base_path, "Data", "StandardisedFormat", paste0(species, "_raw_standardised.csv")))

# Identify sequences of continuous behaviour ------------------------------
# number the consecutive sequences
true_data <- data %>%
  arrange(ID, Time) %>%
  mutate(change_point = ifelse(shift(n = 1, type = 'lag', true_class) == true_class, 0, 1))
true_data$change_point[1] <- 0 # replace the NA with 0
true_data$sequence <- cumsum(true_data$change_point)

# Learn from the training data --------------------------------------------
true_lengths <- true_data %>% 
  group_by(ID, sequence) %>%
  summarise(behaviour = true_class[1], length = length(sequence))
true_summary <- true_lengths %>%
  group_by(behaviour) %>%
  # remove all the 1 second instances (these are problematic for me later)
  filter(!length == 1) %>%
  summarise(mean = round(mean(length),1), max = max(length), min = min(length))

# Use this to logic gate the smoothing ------------------------------------
# begin by figuring out the sequence in the predictions
predicted_data <- data %>%
  arrange(ID, Time) %>%
  mutate(change_point = ifelse(shift(n = 1, type = 'lag', predicted_class) == predicted_class, 0, 1))
predicted_data$change_point[1] <- 0 # replace the NA with 0
predicted_data$sequence <- cumsum(predicted_data$change_point)

predicted_lengths <- predicted_data %>% 
  group_by(sequence) %>%
  summarise(behaviour = predicted_class[1], length = length(sequence))

# go through and logically check each of them
for (event in 0:length(sequence)){
  #  event = 0
  beh <- predicted_lengths$behaviour[predicted_lengths$sequence == event]
  len <- predicted_lengths$length[predicted_lengths$sequence == event]
  
  acceptable_max <- true_summary$max[true_summary$behaviour == beh]
  acceptable_min <- true_summary$min[true_summary$behaviour == beh]
  
  # if length is within the acceptable duration bounds
  if (acceptable_max > len & len > acceptable_min){
    predicted_lengths$acceptable[predicted_lengths$sequence == event] <- TRUE
  } else {
    predicted_lengths$acceptable[predicted_lengths$sequence == event] <- FALSE
  }
}



# Recalculate performance and save ----------------------------------------
performance <- compute_metrics(data$smoothed_class, data$true_class)
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, "DurationSmoothing_performance.csv"))
generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, "DurationSmoothing_performance.pdf"))


