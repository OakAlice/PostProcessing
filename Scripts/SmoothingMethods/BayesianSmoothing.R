# Bayesian Smoothing ------------------------------------------------------
# using the transition probilities and the prediction probibilities

# Code --------------------------------------------------------------------
if(!file.exists(file.path(base_path, "Output", species, paste0("BayesianSmoothing_performance_", i, ".csv")))){
  
  ## Get the transition matrix from the training data -----------------------
  train_data <- fread(file.path(base_path, "Data", species, "Formatted_raw_data.csv")) %>%
    arrange(ID, Time)
  train_data <- identify_sequences(train_data, max_break = ifelse(sample_rates[[species]] > 1, 3, 6)) # based on window duration and buffer
  
  transitions <- generate_transition_probabilities(train_data)
  transition_matrix <- transitions$transition_matrix 
  states <- unique(train_data$Activity)
  
  ## Look at the test data probilities --------------------------------------
  test_data <- fread(file.path(base_path, "Data", species, paste0("Original_predictions_", i, ".csv"))) %>%
    as.data.frame() %>%
    arrange(ID, Time) 
  
  # again, split into sequences and run across each of the sequences
  test_data <- identify_sequences(test_data, max_break = ifelse(sample_rates[[species]] > 1, 3, 6)) # based on window duration and buffer
  test_data$set <- paste(test_data$ID, test_data$sequence, sep = "_")
  
  # run the bayes over each of the sequences and save the smoothed class
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
