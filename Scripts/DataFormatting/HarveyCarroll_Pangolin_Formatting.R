# Formatting the pangolin data --------------------------------------------
sample_rate <- 50

files <- list.files(file.path(base_path, "Data", species, "raw_data"), full.names = TRUE)
data <- lapply(files, function(x){
  df <- fread(x)
  df$ID <- str_split(basename(x), "_")[[1]][1]
  return(df)
})
data <- bind_rows(data)
data <- data %>%
  rename(Time = time,
         Activity = Behavior) %>%
  select(ID, Time, Activity, X, Y, Z)

fwrite(data, file.path(base_path, "Data", species, "Formatted_raw_data.csv"))

# Feature generation ------------------------------------------------------
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
