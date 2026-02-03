# Ecological Case Study ---------------------------------------------------

species <- "Sparkes_Koala"
individual <- "Angelina" # currently just one

# load in the training data and generate the transition matrix
train_data <- fread(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
transition_probs <- generate_transition_probabilities(train_data)
transition_probs_melted <- transition_probs$transition_probs_melted
transition_matrix <- transition_probs$transition_matrix
states <- levels(as.factor(train_data$Activity))

# load in the ecological predictions
original_predictions <- fread(file.path(base_path, "CaseStudy", "Predictions", paste0(individual, "_original_predictions.csv")))
original_predictions <- identify_sequences(original_predictions, max_break = ifelse(sample_rates[[species]] > 1, 2.5, 5.5))
original_predictions$set <- paste(original_predictions$ID, original_predictions$sequence, sep = "_")

# No smoothing ------------------------------------------------------------
if(!file.exists(file.path(base_path, "CaseStudy", "Predictions", "NoSmoothing_predictions.csv"))){
  no_predictions <- original_predictions %>%
    mutate(smoothed_class = predicted_class)
  
  fwrite(no_predictions, file.path(base_path, "CaseStudy", "Predictions", "NoSmoothing_predictions.csv"))
} else {
  print("control already saved")
}

# Mode --------------------------------------------------------------------
if(!file.exists(file.path(base_path, "CaseStudy", "Predictions", "ModeSmoothing_predictions.csv"))){
  mode_data <- rolling_mode_smooth(original_predictions, x = 5)
  
  fwrite(mode_data, file.path(base_path, "CaseStudy", "Predictions", "ModeSmoothing_predictions.csv"))
} else {
  print("already mode smoothed")
}

# Transition --------------------------------------------------------------
if(!file.exists(file.path(base_path, "CaseStudy", "Predictions", "TransitionSmoothing_predictions.csv"))){
  trans_data <- find_suspect_transitions(original_predictions, transition_probs_melted)
  trans_data <- update_suspect_transitions(trans_data, transition_probs_melted)
  
  fwrite(trans_data, file.path(base_path, "CaseStudy", "Predictions", "TransitionSmoothing_predictions.csv"))
} else {
  print("already transition smoothed")
}

# Duration ----------------------------------------------------------------
if(!file.exists(file.path(base_path, "CaseStudy", "Predictions", "DurationSmoothing_predictions.csv"))){
  train_data <- identify_events(train_data, class_col = "true_class")
  duration_information <- generate_duration_summaries(train_data)
  
  dur_data <- identify_events(original_predictions, "predicted_class")
  
  dur_data <- smooth_durations(dur_data, 
                               duration_information$train_summary, 
                               duration_information$minumum_considered_seq_length, 
                               min_rule = "p75")
  
  fwrite(dur_data, file.path(base_path, "CaseStudy", "Predictions", "DurationSmoothing_predictions.csv"))
} else {
  print("already duration smoothed")
}

# Hidden Markov Model -----------------------------------------------------
if(!file.exists(file.path(base_path, "CaseStudy", "Predictions", "HMMSmoothing_predictions.csv"))){
  
  train_data <- fread(file.path(base_path, "Data", species, "Training_predictions_1.csv")) %>%
    na.omit()
  train_data <- identify_sequences(train_data, max_break = ifelse(sample_rates[[species]] > 1, 3, 6)) # based on window duration and buffer
  
  hmm_model <- make_hmm_model(train_data)
  
  # Apply this to the ecological predictions
  # run the hmm over each of the sequences and save the smoothed class
  test_data <- lapply(unique(original_predictions$set), function(x){
    dat <- original_predictions %>% dplyr::filter(set == x)
    if (nrow(dat) < 2) {
      dat$smoothed_class <- dat$predicted_class
      return(dat)
    }
    dat$smoothed_class <- viterbi(hmm_model, as.character(dat$predicted_class))
    
    dat
  })
  test_data <- rbindlist(test_data)
  
  fwrite(test_data, file.path(base_path, "CaseStudy", "Predictions", "HMMSmoothing_predictions.csv"))
} else {
  print("already HMM smoothed")
}

# Bayseian  ---------------------------------------------------------------
if(!file.exists(file.path(base_path, "CaseStudy", "Predictions", "BayesianSmoothing_predictions.csv"))){
  
  original_predictions$set <- paste(original_predictions$ID, original_predictions$sequence, sep = "_")
  
  # run the bayes over each of the sequences and save the smoothed class
  bayes_data <- lapply(unique(original_predictions$set), function(x){
    dat <- original_predictions %>% dplyr::filter(set == x)
    if (nrow(dat) < 3) {
      dat$smoothed_class <- dat$predicted_class
      return(dat)
    }
    dat$smoothed_class <- apply_bayes_smoothing(dat, states, transition_matrix)
    
    dat
  })
  bayes_data <- rbindlist(bayes_data)
  
  fwrite(bayes_data, file.path(base_path, "CaseStudy", "Predictions", "BayesianSmoothing_predictions.csv"))
} else {
  print("already Bayesian smoothed")
}

