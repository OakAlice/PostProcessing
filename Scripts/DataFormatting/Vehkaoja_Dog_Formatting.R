# Vehkaoja_Dog ------------------------------------------------------------
# there is no time in this data (nor in the original data)
# therefore for "time" I've just grouped it into tests, presuming that everything in the test is continuous 

if(!file.exists(file.path(base_path, "Data", "Ladds_Seal", "Formatted_raw_data.csv"))){
  
  sample_rate <- 100
  species <- "Vehkaoja_Dog"
  available_axes <- c("X", "Y", "Z") # the names of the accel axes I'm using
  
  ## Basic formatting -------------------------------------------------------
  files <- list.files(file.path(base_path, "Data", species, "clip_data"), recursive = TRUE, full.names = TRUE)
  raw_data <- lapply(files, function(file) {
    df <- fread(file)
    df <- df %>% mutate(Time = row_number())
    return(df)
  }) 
  raw_data <- bind_rows(raw_data)
  raw_data <- raw_data %>%
    select(V13, Time, V4, V5, V6, V14) %>%
    rename(ID = V13,
           X = V4,
           Y = V5,
           Z = V6,
           Activity = V14)
  
  # save this 
  fwrite(raw_data, file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
  
  ## Generate features ------------------------------------------------------
  if (file.exists(file.path(base_path, "Data", species, "Feature_data.csv"))){
    print("training features already generated")
  } else {
    
    data1 <- fread(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
    
    generated_features <- list()
    for (id in c(65, 66, 67, 68, 70, 72, 73, 74)){ #unique(data1$ID)){
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

  
} else {
  print("file already exists. delete it if you want to regenerate it.")
}