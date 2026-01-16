# Hidden Markov Model Smoothing -------------------------------------------
# a simple ML HMM implementation to smooth the data

# Extract parameters from the training data -------------------------------
  train_data <- fread(file.path(base_path, "Data", species, paste0("Training_predictions_", i, ".csv"))) %>%
    na.omit()
  
  # small bit of data for play
  # train_data <- train_data %>% group_by(true_class) %>% slice_head(n = 200) %>% ungroup()
  
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
  transition_probs <- prop.table(transition_counts, 1)
  
  # calculate the emission probilities
  observations <- levels(as.factor(train_data$predicted_class))
  n_obs <- length(observations)
  
  emission_counts <- matrix(0, n_states, n_obs, dimnames = list(states, observations))
  
  for (j in seq_len(nrow(train_data))) {
    hidden <- as.character(train_data$true_class[j])
    observed <- as.character(train_data$predicted_class[j])
    emission_counts[hidden, observed] <- emission_counts[hidden, observed] + 1
  }
  emission_probs <- prop.table(emission_counts, 1)
  
  # make an HMM based off this information
  hmm_model <- initHMM(
    States = states,
    Symbols = observations,
    startProbs = rep(1 / n_states, n_states), 
    transProbs = transition_probs,
    emissionProbs = emission_probs
  )
  
# NOTE: Is this a totally invalid thing to do?
  # I predicted onto my own training data... that can't be how its meant to be done?
  # I don't have enough data to do it on a clean set though...
  
# Apply this to the test predictions ---------------------------------
test_data <- fread(file.path(base_path, "Data", species, paste0("Original_predictions_", i, ".csv"))) %>%
  as.data.frame() %>%
  arrange(ID, Time) 

# Convert index back to class labels
test_data$smoothed_class <- viterbi(hmm_model, as.factor(test_data$predicted_class))

# Recalculate performance and save ----------------------------------------
performance <- compute_metrics(as.factor(test_data$smoothed_class), as.factor(test_data$true_class))
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, paste0("HMMSmoothing_performance_", i, ".csv")))
# generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, paste0("HMMSmoothing_performance_", i, ".pdf")))
