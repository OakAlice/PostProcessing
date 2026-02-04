# Testing performance of base predictions ---------------------------------

if(!file.exists(file.path(base_path, "Output", species, paste0("NoSmoothing_performance_", i, ".csv")))){
    
  # loading in the standardised formats
  data <- fread(file.path(base_path, "Data", species, paste0("Original_predictions_", i, ".csv")))
  data <- identify_sequences(data, max_break = ifelse(sample_rates[[species]] > 1, 2.5, 5.5)) # looking at the window breaks but with a little safety buffer
  
  # no smoothing is performed, therefore just duplicate and rename the column without doing anything
  data <- data %>% mutate(smoothed_class = predicted_class)
  
  # now run it through the standardised performance testing mechanism
  # performance metrics
  performance <- compute_metrics(as.factor(data$smoothed_class), as.factor(data$true_class))
  metrics <- performance$metrics
  
  # save these
  fwrite(metrics, file.path(base_path, "Output", species, paste0("NoSmoothing_performance_", i, ".csv")))
  #if(i == 1){
    predictions <- data %>% select(ID, Time, smoothed_class, true_class)
    fwrite(predictions, file.path(base_path, "Output", species, paste0("NoSmoothing_predictions_", i, ".csv")))
  #}
  #generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, paste0("NoSmoothing_performance_", i, ".pdf")))

} else {
  print("NoSmoothing already calculated")
}
