# Hidden Markov Model Smoothing -------------------------------------------
# a simple ML HMM implementation to smooth the data

if(!file.exists(file.path(base_path, "Output", species, paste0("HMMSmoothing_performance_", i, ".csv")))){
  
# Extract parameters from the training data -------------------------------
  train_data <- fread(file.path(base_path, "Data", species, paste0("Training_predictions_", i, ".csv"))) %>%
    na.omit()
  train_data <- identify_sequences(train_data, max_break = ifelse(sample_rates[[species]] > 1, 3, 6)) # based on window duration and buffer
  
  # calculate the transition probilities
  # this is slightly different from the transition method in that I'm pulling from the predictions (which are windowed)
  # rather than the raw data
  states <- levels(as.factor(train_data$true_class))
  n_states <- length(states)
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
    startProbs = rep(1 / n_states, n_states), # uniform because sampling starts are quite random
    transProbs = transition_probs,
    emissionProbs = emission_probs
  )
  
# Apply this to the test predictions ---------------------------------
test_data <- fread(file.path(base_path, "Data", species, paste0("Original_predictions_", i, ".csv"))) %>%
  arrange(ID, Time)
# chop into continuous sequences
test_data <- identify_sequences(test_data, max_break = ifelse(sample_rates[[species]] > 1, 3, 6)) # based on window duration and buffer
test_data$set <- paste(test_data$ID, test_data$sequence, sep = "_")

# run the hmm over each of the sequences and save the smoothed class
test_data <- lapply(unique(test_data$set), function(x){
  dat <- test_data %>% dplyr::filter(set == x)
  if (nrow(dat) < 2) {
    dat$smoothed_class <- dat$predicted_class
    return(dat)
  }
  dat$smoothed_class <- viterbi(hmm_model, as.character(dat$predicted_class))
  
  dat
})
test_data <- rbindlist(test_data)

# Recalculate performance and save ----------------------------------------
performance <- compute_metrics(as.factor(test_data$smoothed_class), as.factor(test_data$true_class))
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, paste0("HMMSmoothing_performance_", i, ".csv")))
# generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, paste0("HMMSmoothing_performance_", i, ".pdf")))


} else {
  print("HMMSmoothing already calculated")
}
