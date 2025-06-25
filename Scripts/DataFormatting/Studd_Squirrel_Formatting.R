# Formatting the squirrel data --------------------------------------------
# another nice and easy one

# read in the data
sample_rate <- 1
data <- fread(file.path(base_path, "Data", species, "Studd_2019.csv"))


data <- data %>%
  select(TIME, BEHAV, X, Y, Z, LCOLOUR, RCOLOUR) %>%
  mutate(ID = paste0(LCOLOUR, RCOLOUR)) %>%
  rename(Time = TIME,
         Activity = BEHAV) %>%
  select(!c(LCOLOUR, RCOLOUR))

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
                                     window_length = 5, # this one is longer than the others
                                     sample_rate = sample_rate, 
                                     overlap_percent = 10)
    
    generated_features[[id]] <- feature_data
  }
  generated_features_df <- bind_rows(generated_features)
  fwrite(generated_features_df, file.path(base_path, "Data", species, "Feature_data.csv"))
}