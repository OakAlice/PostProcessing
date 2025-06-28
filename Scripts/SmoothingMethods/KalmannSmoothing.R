# Smoothing method using the kalmann filter -------------------------------

# Function ---------------------------------------------------------------
apply_kalman_smoothing <- function(data, states, F, process_var = 1e-5, obs_var = 1e-2) {
  setDT(data)
  
  n_time <- nrow(data)
  n_class <- length(states)
  
  smoothed_probs <- matrix(0, n_time, n_class)
  colnames(smoothed_probs) <- states
  
  # Initialize latent state with first observation (normalized)
  x <- as.numeric(data[1, ..states])
  x <- x / sum(x)
  smoothed_probs[1, ] <- x
  
  # Initial uncertainty and noise terms
  P <- diag(n_class) * 1       # Initial state uncertainty
  Q <- diag(process_var, n_class)  # Process noise
  R <- diag(obs_var, n_class)      # Observation noise
  
  for (t in 2:n_time) {
    # Predict: use transition matrix F
    x_pred <- F %*% x
    P_pred <- F %*% P %*% t(F) + Q
    
    # Observation: classifier output at time t
    z <- as.numeric(data[t, ..states])
    z <- z / sum(z)
    
    # Update
    S <- P_pred + R
    K <- P_pred %*% solve(S)         # Kalman gain
    x <- x_pred + K %*% (z - x_pred) # Update state
    P <- (diag(n_class) - K) %*% P_pred
    
    # Normalize and store
    x <- x / sum(x)
    smoothed_probs[t, ] <- x
  }
  
  # Get final class prediction from smoothed probabilities
  smoothed_class <- colnames(smoothed_probs)[max.col(smoothed_probs, ties.method = "first")]
  data$smoothed_class <- smoothed_class
  
  return(data)
}

# Transition probs --------------------------------------------------------
train_data <- fread(file = file.path(base_path, "Data", species, "Training_predictions.csv")) %>%
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

for (i in seq_len(nrow(transitions))) {
  from <- as.character(transitions$true_class[i])
  to <- as.character(transitions$next_state[i])
  transition_counts[from, to] <- transition_counts[from, to] + 1
}
transition_matrix <- prop.table(transition_counts, 1)

# Code --------------------------------------------------------------------
test_data <- fread(file.path(base_path, "Data", species, "Original_predictions.csv")) %>%
  as.data.frame() %>%
  arrange(ID, Time) 
states <- levels(as.factor(test_data$true_class))
test_data <- apply_kalman_smoothing(data = test_data, 
                                    states, 
                                    F = transition_matrix,
                                    process_var = 1e-4, obs_var = 1e-2)

## Recalculate performance and save ----------------------------------------
performance <- compute_metrics(as.factor(test_data$smoothed_class), as.factor(test_data$true_class))
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, "KalmanSmoothing_performance.csv"))
generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, "BayesianSmoothing_performance.pdf"))

# Calculate ecological results --------------------------------------------
if (file.exists(file.path(base_path, "Data", species, "Unlabelled_predictions.csv"))){
  ecological_data <- fread(file.path(base_path, "Data", species, "Unlabelled_predictions.csv"))
  
  ecological_data <- apply_kalman_smoothing(data = ecological_data,
                                            states, 
                                            F = transition_matrix,
                                            process_var = 1e-4, obs_var = 1e-2)
  
  # calculate what this means
  eco <- ecological_analyses(smoothing_type = "Bayesian", 
                             eco_data = ecological_data, 
                             target_activity = target_activity)
  question1 <- eco$sequence_summary
  question2 <- eco$hour_proportions
  
  # write these to files
  fwrite(question1, file.path(base_path, "Output", species, "KalmanSmoothing_eco1.csv"))
  fwrite(question2, file.path(base_path, "Output", species, "KalmanSmoothing_eco2.csv"))
} else {
  print("there is no ecological data for this dataset")
}

