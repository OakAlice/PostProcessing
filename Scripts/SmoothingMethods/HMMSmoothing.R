# Hidden Markov Model Smoothing -------------------------------------------
# a simple ML HMM implementation to smooth the data

if(!file.exists(file.path(base_path, "Output", species, paste0("HMMSmoothing_performance_", i, ".csv")))){
  
  # Extract parameters from the training data -------------------------------
  train_data <- fread(file.path(base_path, "Data", species, paste0("Training_predictions_", i, ".csv"))) %>%
    na.omit()
  train_data <- identify_sequences(train_data, max_break = ifelse(sample_rates[[species]] > 1, 3, 6)) # based on window duration and buffer
  
  # train a model
  hmm_model <- make_hmm_model(train_data)
  
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