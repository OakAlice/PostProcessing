# Formatting the cat data --------------------------------------------
# this paper was replication of Galea paper, so data already in format

# variables
sample_rate <- 30
  
data <- fread(file.path(base_path, "Data", species, "Smit_Cat_Labelled.csv"))

data <- data %>%
  rename(Time = datetime,
         X = Accelerometer.X,
         Y = Accelerometer.Y,
         Z = Accelerometer.Z) %>%
  select(ID, Time, Activity, X, Y, Z)

fwrite(data, file.path(base_path, "Data", species, "Formatted_raw_data.csv"))


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