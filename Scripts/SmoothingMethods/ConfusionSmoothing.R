# Confusion Smoothing -----------------------------------------------------
# not all predictions are created equal
# the confusion matrix from the model creation step tells us information about which predictions are better than others
# using this information we will improve on duration based smoothing
# TODO: Is there an issue of leakage here because learning from test data???

# Function ----------------------------------------------------------------
applying_confusion_changes <- function(data, confusion_likelihood, threshold = 0.5){
  
  # Detect change points
  data <- data %>%
    arrange(ID, Time) %>%
    group_by(ID) %>%
    mutate(
      change_point = if_else(lag(predicted_class) == predicted_class, 0L, 1L),
      change_point = replace_na(change_point, 0L)
    ) %>%
    ungroup()
  
  # Initialise smoothed_class as predicted_class by default
  data$smoothed_class <- data$predicted_class
  
  candidate_idx <- which(
    data$change_point == 1 &
      data$ID == lag(data$ID) &
      data$ID == lead(data$ID)
  )
  
  # Return early if no candidates
  if (length(candidate_idx) == 0) return(data)
  
  before <- data$predicted_class[candidate_idx - 1]
  event  <- data$predicted_class[candidate_idx]
  after  <- data$predicted_class[candidate_idx + 1]
  
  # Skip if event is same as neighbor (i.e. part of sequence)
  same_as_neighbors <- event == before | event == after
  
  # get probabilities from the confusion matrix
  conf_dt <- copy(confusion_likelihood)
  setDT(conf_dt)
  setkey(conf_dt, predicted_class)

  lookup_pairs <- data.frame(true_class = before, predicted_class = event)
  conf_df <- as.data.frame(conf_dt)
  result <- left_join(lookup_pairs, conf_df, by = c("true_class", "predicted_class"))
  prob_before <- result$likelihood_classification
  
  lookup_pairs2 <- data.frame(true_class = after, predicted_class = event)
  result <- left_join(lookup_pairs2, conf_df, by = c("true_class", "predicted_class"))
  prob_after <- result$likelihood_classification
  
  # group all that info together
  result <- data.table(
    idx = candidate_idx,
    before = before,
    after = after,
    event = event,
    prob_before = prob_before,
    prob_after = prob_after,
    same_as_neighbors = same_as_neighbors
  )
  
  # logic to smooth or not
  set(result, j = "max_prob", value = pmax(result$prob_before, result$prob_after, na.rm = TRUE))
  set(result, j = "label", value = fifelse(result$prob_before >= result$prob_after, result$before, result$after))
  
  # Only update if above threshold and not part of a sequence
  valid <- result[!same_as_neighbors & !is.na(max_prob) & max_prob > threshold]
  
  if (nrow(valid) > 0) {
    data$smoothed_class[valid$idx] <- valid$label
  }
  
  return(data)
}

# Code --------------------------------------------------------------------
## Test -------------------------------------------------------------------
# generate the confusion matrix
data <- fread(file.path(base_path, "Data", "StandardisedPredictions", paste0(species, "_test_data.csv")))
performance <- compute_metrics(data$predicted_class, data$true_class)
confusion <- as.matrix(performance$conf_matrix_padded)

# generate a miscalssification likelihood table
# interpretation: given the pred_class, there is a % likelihood that its actually the true_class
# when pred = true, hopefully a high % but also provides misclassification rates
confusion_likelihood <- as.data.frame(as.table(confusion)) %>%
  rename(true_class = 1, predicted_class = 2, n = Freq) %>% # 1 and 2 are the dimnames
  group_by(true_class) %>%
  mutate(
    total = sum(n),
    likelihood_classification = round(n / total, 2)
  ) %>%
  ungroup() %>%
  arrange(true_class, desc(likelihood_classification))

# Apply to the test data 
data <- applying_confusion_changes(data, confusion_likelihood, threshold = 0.3)

# Recalculate performance and save
performance <- compute_metrics(data$smoothed_class, data$true_class)
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, "ConfusionSmoothing_performance.csv"))
generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, "ConfusionSmoothing_performance.pdf"))

## Calculate ecological results --------------------------------------------
ecological_data <- fread(file.path(base_path, "Data", "UnlabelledData", paste0(species, "_unlabelled_predicted.csv")))

ecological_data <- applying_confusion_changes(ecological_data, confusion_likelihood, threshold = 0.1)

# calculate what this means
eco <- ecological_analyses(smoothing_type = "Confusion", 
                           eco_data = ecological_data, 
                           target_activity = target_activity)
question1 <- eco$sequence_summary
question2 <- eco$hour_proportions

# write these to files
fwrite(question1, file.path(base_path, "Output", species, "ConfusionSmoothing_eco1.csv"))
fwrite(question2, file.path(base_path, "Output", species, "ConfusionSmoothing_eco2.csv"))
