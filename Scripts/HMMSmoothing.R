# Hidden Markov Model Smoothing -------------------------------------------
# a simple ML HMM implementation to smooth the data
# copied this tutorial: https://www.geeksforgeeks.org/hidden-markov-model-in-r/

# Train the HMM -----------------------------------------------------------
if (exists(file.path(base_path, "Output", species, "hmm_model_fitted.rds"))){
  hmm_model <- readRDS(file.path(base_path, "Output", species, "hmm_model_fitted.rds"))
} else {
  train_data <- fread(file.path(base_path, "Data", "StandardisedFormat", paste0(species, "_raw_train_standardised.csv"))) %>%
    as.data.frame() %>%
    arrange(ID, Time) %>%
    filter(!true_class == "") %>%
    mutate(true_class = as.factor(true_class))
  
  seq_lengths <- as.numeric(table(train_data$ID))
  n_states <- length(unique(train_data$true_class))
  
  hmm_model <- depmix(true_class ~ 1, 
                      family = multinomial(),
                      nstates = n_states, 
                      data = train_data,
                      ntimes = seq_lengths)
  
  hmm_fit <- fit(hmm_model)
  saveRDS(hmm_fit, file.path(base_path, "Output", species, "hmm_model_fitted.rds"))
}

# Dummy model on test predictions -----------------------------------------
# and then replace the parameters
# this is just how this package happens to work - have to do it
test_data <- fread(file.path(base_path, "Data", "StandardisedFormat", paste0(species, "_raw_test_standardised.csv"))) %>%
  as.data.frame() %>%
  arrange(ID, Time) %>%
  filter(predicted_class != "") %>%
  mutate(predicted_class = as.factor(predicted_class)) %>%
  dplyr::select(-true_class) %>% # temporarily started calling wrong package for some reason???
  rename(true_class = predicted_class) # rename predicted to true to match training model

seq_lengths_test <- as.numeric(table(test_data$ID))

# Build a new HMM model with the same structure but using predicted classes
hmm_test <- depmix(response = true_class ~ 1,
                   data = test_data,
                   nstates = n_states,
                   family = multinomial(),
                   ntimes = seq_lengths_test)

# Copy parameters from the trained model
hmm_test <- setpars(hmm_test, getpars(hmm_fit))

# Decode most likely hidden state sequence
smoothed <- posterior(hmm_test, type = "viterbi")

# comvert back to names not numbers and add to dataset
test_data$smoothed_class <- levels(train_data$true_class)[smoothed$state]

# Recalculate performance and save ----------------------------------------
performance <- compute_metrics(test_data$smoothed_class, test_data$true_class)
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, "HMMSmoothing_performance.csv"))
generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, "HMMSmoothing_performance.pdf"))


