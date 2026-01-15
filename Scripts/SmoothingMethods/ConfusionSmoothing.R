# Confusion Smoothing -----------------------------------------------------



# Archived this script and no longer using this method



# not all predictions are created equal
# the confusion matrix from the model creation step tells us information about which predictions are better than others
# using this information we will improve on duration based smoothing
# TODO: Is learning from the training data really meaningles here?

# Function ----------------------------------------------------------------
applying_confusion_changes <- function(data, confusion_likelihood){
  
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

  lookup_pairs <- data.frame(true_class = as.factor(before), predicted_class = as.factor(event))
  conf_df <- as.data.frame(conf_dt)
  result <- left_join(lookup_pairs, conf_df, by = c("true_class", "predicted_class"))
  prob_before <- result$likelihood_classification
  
  lookup_pairs2 <- data.frame(true_class = as.factor(after), predicted_class = as.factor(event))
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
  
  # defining the threshold based on chance
  chance_threshold <- 1/length(unique(data$true_class))
  
  # Only update if above threshold and not part of a sequence
  valid <- result[!same_as_neighbors & !is.na(max_prob) & max_prob > chance_threshold * 2]
  
  if (nrow(valid) > 0) {
    data$smoothed_class[valid$idx] <- valid$label
  }
  
  return(data)
}

# Code --------------------------------------------------------------------
## Test -------------------------------------------------------------------
# generate the confusion matrix
train_data <- fread(file.path(base_path, "Data", species, "Training_predictions.csv")) %>%
  na.omit()
performance <- compute_metrics(as.factor(train_data$predicted_class), as.factor(train_data$true_class))
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
test_data <- fread(file.path(base_path, "Data", species, "Original_predictions.csv")) %>%
  as.data.frame() %>%
  arrange(ID, Time) 
data <- applying_confusion_changes(data = test_data, confusion_likelihood)

# Recalculate performance and save
performance <- compute_metrics(as.factor(data$smoothed_class), as.factor(data$true_class))
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, "ConfusionSmoothing_performance.csv"))
generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, "ConfusionSmoothing_performance.pdf"))
