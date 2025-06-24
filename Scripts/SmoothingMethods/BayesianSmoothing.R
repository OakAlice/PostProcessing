# Bayesian Smoothing ------------------------------------------------------
# using the transition probilities and the prediction probibilities

# Functions ---------------------------------------------------------------
apply_bayes_smoothing <- function(data, states){
  
  setDT(data)
  
  # make something to store it in
  n_time <- nrow(data)
  n_class <- length(states)
  smoothed_probs <- matrix(0, n_time, n_class)
  colnames(smoothed_probs) <- states
  
  # Set a basic uniform prior
  prior <- rep(1 / n_class, n_class)  # uniform prior
  smoothed_probs[1, ] <- prior * as.numeric(data[1, ..states]) # .. means doesnt literally search for "states"
  smoothed_probs[1, ] <- smoothed_probs[1, ] / sum(smoothed_probs[1, ])
  
  # Recursively apply Bayesian update
  for (t in 2:n_time) {
    # Predict next prior using transition matrix
    prior <- transition_matrix %*% smoothed_probs[t - 1, ]
    
    # Multiply with likelihood from classifier
    likelihood <- as.numeric(data[t, ..states])
    posterior <- prior * likelihood
    
    # Normalize
    smoothed_probs[t, ] <- posterior / sum(posterior)
  }
  
  # Select the highest one --------------------------------------------------
  smoothed_class <- colnames(smoothed_probs)[max.col(smoothed_probs, ties.method = "first")]
  data$smoothed_class <- smoothed_class
  
  return(data)
}

# Code --------------------------------------------------------------------
## Get the transition matrix from the training data -----------------------
train_data <- fread(file.path(base_path, "Data", species, "Training_predictions.csv")) %>%
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

## Look at the test data probilities --------------------------------------
test_data <- fread(file.path(base_path, "Data", species, "Original_predictions.csv")) %>%
  as.data.frame() %>%
  arrange(ID, Time) 

test_data <- apply_bayes_smoothing(test_data, states)

## Recalculate performance and save ----------------------------------------
performance <- compute_metrics(as.factor(test_data$smoothed_class), as.factor(test_data$true_class))
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, "BayesianSmoothing_performance.csv"))
generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, "BayesianSmoothing_performance.pdf"))

# Calculate ecological results --------------------------------------------
if (file.exists(file.path(base_path, "Data", species, "Unlabelled_predictions.csv"))){
  ecological_data <- fread(file.path(base_path, "Data", species, "Unlabelled_predictions.csv"))
  ecological_data <- apply_bayes_smoothing(data = ecological_data, states)

  # calculate what this means
  eco <- ecological_analyses(smoothing_type = "Bayesian", 
                             eco_data = ecological_data, 
                             target_activity = target_activity)
  question1 <- eco$sequence_summary
  question2 <- eco$hour_proportions
  
  # write these to files
  fwrite(question1, file.path(base_path, "Output", species, "BayesianSmoothing_eco1.csv"))
  fwrite(question2, file.path(base_path, "Output", species, "BayesianSmoothing_eco2.csv"))
} else {
  print("there is no ecological data for this dataset")
}

