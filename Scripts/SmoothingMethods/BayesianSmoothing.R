# Bayesian Smoothing ------------------------------------------------------
# using the transition probilities and the prediction probibilities

# Functions ---------------------------------------------------------------
apply_bayes_smoothing <- function(data, states, transition_matrix) {
  
  # sometimes the model predicts fewer classes than are in the training data, and so we get an imbalance
  # these steps are designed to allow the model to function even without all classes predicted
  
  setDT(data)
  
  n_time  <- nrow(data)
  n_class <- length(states)
  
  smoothed_probs <- matrix(0, n_time, n_class)
  colnames(smoothed_probs) <- states
  
  # get the liklihood
  get_likelihood <- function(dt_row, states) {
    lik <- rep(0, length(states))
    names(lik) <- states
    
    present <- intersect(states, names(dt_row))
    lik[present] <- as.numeric(dt_row[, ..present])
    
    lik
  }

  prior <- rep(1 / n_class, n_class)
  
  likelihood <- get_likelihood(data[1], states)
  posterior  <- prior * likelihood
  
  if (sum(posterior) == 0) {
    posterior <- prior
  } else {
    posterior <- posterior / sum(posterior)
  }
  
  smoothed_probs[1, ] <- posterior
  
  # do the bayes filter recursivly
  for (t in 2:n_time) {
    
    # prediction step
    prior <- as.numeric(transition_matrix %*% smoothed_probs[t - 1, ])
    
    # update step
    likelihood <- get_likelihood(data[t], states)
    posterior  <- prior * likelihood
    
    if (sum(posterior) == 0) {
      posterior <- prior
    } else {
      posterior <- posterior / sum(posterior)
    }
    
    smoothed_probs[t, ] <- posterior
  }
  
  # put in the sequence
  smoothed_class <- colnames(smoothed_probs)[
    max.col(smoothed_probs, ties.method = "first")
  ]
  
  smoothed_class
}


# Code --------------------------------------------------------------------
if(!file.exists(file.path(base_path, "Output", species, paste0("BayesianSmoothing_performance_", i, ".csv")))){
  
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
  if (nrow(dat) < 3) {
    dat$smoothed_class <- dat$predicted_class
    return(dat)
  }
  dat$smoothed_class <- apply_bayes_smoothing(dat, states, transition_matrix)
  
  dat
})
test_data <- rbindlist(test_data)

## Recalculate performance and save ----------------------------------------
performance <- compute_metrics(as.factor(test_data$smoothed_class), as.factor(test_data$true_class))
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, paste0("BayesianSmoothing_performance_", i, ".csv")))
# generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, paste0("BayesianSmoothing_performance_", i, ".pdf")))


} else {
  print("BayesianSmoothing already calculated")
}
