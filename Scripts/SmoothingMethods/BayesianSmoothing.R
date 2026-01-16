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
  data$smoothed_class <- smoothed_class
  
  return(data)
}

# Code --------------------------------------------------------------------
## Get the transition matrix from the training data -----------------------
train_data <- fread(file.path(base_path, "Data", species, paste0("Training_predictions_", i, ".csv"))) %>%
  na.omit()

states <- levels(as.factor(train_data$true_class))
n_states <- length(states)

# calculate the transition probilities
transition_counts <- matrix(0, n_states, n_states, dimnames = list(states, states))
train_data <- train_data %>%
  arrange(ID, Time) %>%
  group_by(ID) %>%
  mutate(next_state = lead(true_class)) %>%
  ungroup()

transitions <- na.omit(train_data[, c("true_class", "next_state")])

for (j in seq_len(nrow(transitions))) {
  from <- as.character(transitions$true_class[j])
  to <- as.character(transitions$next_state[j])
  transition_counts[from, to] <- transition_counts[from, to] + 1
}
transition_matrix <- prop.table(transition_counts, 1)

## Look at the test data probilities --------------------------------------
test_data <- fread(file.path(base_path, "Data", species, paste0("Original_predictions_", i, ".csv"))) %>%
  as.data.frame() %>%
  arrange(ID, Time) 

test_data <- apply_bayes_smoothing(test_data, states, transition_matrix)

## Recalculate performance and save ----------------------------------------
performance <- compute_metrics(as.factor(test_data$smoothed_class), as.factor(test_data$true_class))
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, paste0("BayesianSmoothing_performance_", i, ".csv")))
# generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, paste0("BayesianSmoothing_performance_", i, ".pdf")))
