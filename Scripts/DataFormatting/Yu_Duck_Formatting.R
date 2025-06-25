# Formatting the duck data ------------------------------------------------

# variables
sample_rate <- 25


files <- list.files(file.path(base_path, "Data", species, "behaviours"), full.names = TRUE)

if (file.exists(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))){
  print("data already formatted")
} else {
    
    
  # read them toggether 
  data <- lapply(files, function(x){
    df <- fread(x)
    name <- strsplit(basename(x), "_")[[1]][1]
    df$name <- name
    df$timestamp2 <- as.POSIXct(df$timestamp, format = "%d/%m/%y %H:%M", tz = "UTC")
    df <- df[, c("x", "y", "z", "timestamp2", "behaviour", "name")]
  }
  )
  data <- bind_rows(data)
  
  # format that
  data <- data %>%
    rename(ID = name,
           Activity = behaviour,
           X = x,
           Y = y,
           Z = z,
           Time = timestamp2)
  
  # split labelled and unlabelled
  labelled <- data %>% filter(!Activity == "")
  unlabelled <- data %>% filter(Activity == "") # there isn't really enough of this to qualify as much??? just ignore it
  
  fwrite(labelled, file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
}

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
