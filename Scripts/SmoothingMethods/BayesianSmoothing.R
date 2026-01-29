# Bayesian Smoothing ------------------------------------------------------
# using the transition probilities and the prediction probibilities

# Functions ---------------------------------------------------------------
apply_bayes_smoothing <- function(data, states, transition_matrix){
  
  setDT(data)
  
  # make something to store it in
  n_time <- nrow(data)
  n_class <- length(states)
  smoothed_probs <- matrix(0, n_time, n_class)
  colnames(smoothed_probs) <- states
  
  # Set a basic uniform prior
  prior <- rep(1 / n_class, n_class)  # uniform prior
  smoothed_probs[1, ] <- prior * as.numeric(data[1, ..states]) # '..' means doesnt literally search for "states"
  smoothed_probs[1, ] <- smoothed_probs[1, ] / sum(smoothed_probs[1, ])
  
  # Recursively apply Bayesian update
  for (t in 2:n_time) {
    # Predict next prior using transition matrix
    prior <- transition_matrix %*% smoothed_probs[t - 1, ]
    
    # Multiply with likelihood from classifier
    likelihood <- as.numeric(data[t, ..states])
    posterior <- prior * likelihood
    
    # Normalise
    smoothed_probs[t, ] <- posterior / sum(posterior)
  }
  
  # Select the highest one --------------------------------------------------
  smoothed_class <- colnames(smoothed_probs)[max.col(smoothed_probs, ties.method = "first")]
  
  return(smoothed_class)
}

# Code --------------------------------------------------------------------
## Get the transition matrix from the training data -----------------------
train_data <- fread(file.path(base_path, "Data", species, "Formatted_raw_data.csv")) %>%
  arrange(ID, Time)
train_data <- identify_sequences(train_data, max_break = ifelse(sample_rates[[species]] > 1, 3, 6)) # based on window duration and buffer

states <- levels(as.factor(train_data$Activity))
n_states <- length(states)

# calculate the transitions within continuous sequences
transition_counts <- matrix(0, n_states, n_states, dimnames = list(states, states))
train_data <- train_data %>%
  group_by(ID, sequence) %>%
  arrange(Time, .by_group = TRUE) %>%
  mutate(next_state = lead(Activity)) %>%
  ungroup()
transitions <- na.omit(train_data[, c("Activity", "next_state")]) # remove the ones that are last in sequence

# probability of each of these transitions
for (j in seq_len(nrow(transitions))) {
  from <- as.character(transitions$Activity[j])
  to <- as.character(transitions$next_state[j])
  transition_counts[from, to] <- transition_counts[from, to] + 1
}
transition_matrix <- prop.table(transition_counts, 1)

## Look at the test data probilities --------------------------------------
test_data <- fread(file.path(base_path, "Data", species, paste0("Original_predictions_", i, ".csv"))) %>%
  as.data.frame() %>%
  arrange(ID, Time) 

# again, split into sequences and run across each of the sequences
test_data <- identify_sequences(test_data, max_break = ifelse(sample_rates[[species]] > 1, 3, 6)) # based on window duration and buffer
test_data$set <- paste(test_data$ID, test_data$sequence, sep = "_")

# run the hmm over each of the sequences and save the smoothed class
test_data <- lapply(unique(test_data$set), function(x){
  dat <- test_data %>% dplyr::filter(set == x)
  if (nrow(dat) < 2) {
    dat$smoothed_class <- dat$predicted_class
    return(dat)
  }
  dat$smoothed_class <- apply_bayes_smoothing(dat, states, transition_matrix)
  
  dat
})

## Recalculate performance and save ----------------------------------------
performance <- compute_metrics(as.factor(test_data$smoothed_class), as.factor(test_data$true_class))
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, paste0("BayesianSmoothing_performance_", i, ".csv")))
# generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, paste0("BayesianSmoothing_performance_", i, ".pdf")))
