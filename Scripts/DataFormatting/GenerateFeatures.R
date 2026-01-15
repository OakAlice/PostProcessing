# Code to generate features from all the data -----------------------------

# Generate the features ---------------------------------------------------
if (file.exists(file.path(base_path, "Data", species, "Feature_data.csv"))){
  print("training features already generated")
} else {
  
  data1 <- fread(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
  
  # Firstly subset the data to an approporiate volume 
  # just so it doesn't take 1 million years to process
  sample_rate <- sample_rates[[species]] 
  max_slices <- 600 * sample_rate # maximum of 10 minutes per behaviour per individual
  data1 <- data1 %>% group_by(ID, Activity) %>% arrange(Time) %>% slice(1:max_slices)
  # TODO: This may be too aggressive, I may have to undo this
  
  # generate the features
  generated_features <- list()
  for (id in unique(data1$ID)){
    data <- data1 %>% 
      dplyr::filter(ID == id) %>% 
      as.data.table()
    
    feature_data <- processDataPerID(data, 
                                     features_type = c("timeseries", "statistical"), 
                                     window_length = 2, # to give it more data to work with 
                                     sample_rate = sample_rate, 
                                     overlap_percent = overlap)
    
    generated_features[[id]] <- feature_data
  }
  generated_features_df <- bind_rows(generated_features)
  fwrite(generated_features_df, file.path(base_path, "Data", species, "Feature_data.csv"))
}


