# Ladds_Seal --------------------------------------------------------------
# this one is easy

sample_rate <- 25
species <- "Ladds_Seal"
available_axes <- c("X", "Y", "Z") # the names of the accel axes I'm using

raw_files <- list.files(file.path(base_path, "Data", species, "Raw_Data"), recursive = TRUE, full.names = TRUE)

# Basic Formatting --------------------------------------------------------
# add column for ID
raw_data <- lapply(raw_files, function(file) {
  df <- read.csv(file)
  id <- basename(dirname(file))  # get the lowest folder name
  df$ID <- id
  return(df)
})
raw_data <- bind_rows(raw_data)

# format
raw_data <- raw_data %>%
  select(ID, time, x, y, z, behaviour, type, location) %>%
  rename(Time = time,
         X = x,
         Y = y,
         Z = z,
         Activity = behaviour,
         GeneralisedActivity = type,
         Context = location)

# save this 
fwrite(raw_data, file.path(base_path, "Data", "Ladds_Seal", "Formatted_raw_data.csv"))

## Generate features ------------------------------------------------------
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
