# Formatting the cat data -------------------------------------------------

sample_rate <- 40

if(!file.exists(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))){

  file <- list.files(file.path(base_path, "Data", species), recursive = TRUE, full.names = TRUE)

  df <- read.csv(file)
  
  df <- df %>%
    rename(X = AccX,
           Y = AccY,
           Z = AccZ,
           Activity = Behaviour)
  
  # save this 
  fwrite(df, file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
}

# Features ----------------------------------------------------------------
if (file.exists(file.path(base_path, "Data", species, "Feature_data.csv"))){
  print("training features already generated")
} else {
  
  data1 <- fread(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
  
  generated_features <- list()
  for (id in unique(data1$ID)){
    data <- data1 %>% 
      filter(ID == id) %>% 
      filter(!Activity == "") %>% 
      as.data.table()
    
    feature_data <- processDataPerID(data, 
                                     features_type = c("timeseries", "statistical"), 
                                     window_length = 1, # this is in seconds, 
                                     sample_rate = sample_rate, 
                                     overlap_percent = 10)
    
    generated_features[[id]] <- feature_data
  }
  generated_features_df <- bind_rows(generated_features)
  fwrite(generated_features_df, file.path(base_path, "Data", species, "Feature_data.csv"))
}

