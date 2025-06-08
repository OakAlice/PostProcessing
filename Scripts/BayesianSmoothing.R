# Bayesian Smoothing ------------------------------------------------------
# using the transition probilities and the prediction probibilities

# Get the transition matrix from the training data ------------------------
train_data <- fread(file.path(base_path, "Data", "StandardisedFormat", paste0(species, "_train_data.csv"))) %>%
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

# Look at the test data probilities ---------------------------------------
test_data <- fread(file.path(base_path, "Data", "StandardisedFormat", paste0(species, "_test_data.csv"))) %>%
  as.data.frame() %>%
  arrange(ID, Time) 

# make something to store it in
n_time <- nrow(test_data)
n_class <- length(states)
smoothed_probs <- matrix(0, n_time, n_class)
colnames(smoothed_probs) <- states

# Set a basic uniform prior
prior <- rep(1 / n_class, n_class)  # uniform prior
smoothed_probs[1, ] <- prior * as.numeric(test_data[1, states])
smoothed_probs[1, ] <- smoothed_probs[1, ] / sum(smoothed_probs[1, ])

# Recursively apply Bayesian update
for (t in 2:n_time) {
  # Predict next prior using transition matrix
  prior <- transition_matrix %*% smoothed_probs[t - 1, ]
  
  # Multiply with likelihood from classifier
  likelihood <- as.numeric(test_data[t, states])
  posterior <- prior * likelihood
  
  # Normalize
  smoothed_probs[t, ] <- posterior / sum(posterior)
}
# Select the highest one --------------------------------------------------
smoothed_class <- colnames(smoothed_probs)[max.col(smoothed_probs, ties.method = "first")]
test_data$smoothed_class <- smoothed_class

# Recalculate performance and save ----------------------------------------
performance <- compute_metrics(test_data$smoothed_class, test_data$true_class)
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, "BayesianSmoothing_performance.csv"))
generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, "BayesianSmoothing_performance.pdf"))
