# Formatting for bear dataset ---------------------------------------------
library(data.table)
library(dplyr)

# variables
sample_rate <- 16 #hz

if (file.exists(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))){
  print("data already formatted")
} else {
    
  accel <- fread(file.path(base_path, "Data", species, "PolarBear_archival_logger_data_southernBeaufortSea_2014_2016_revised.csv"))
  behs <- fread(file.path(base_path, "Data", species, "PolarBear_video-derived_behaviors_southernBeaufortSea_2014_2016_revised.csv"))
  
  # theyre big, so going to use table instead of frame conventions
  setDT(behs)
  setDT(accel)
  
  # Convert dattime to POSIXct for easy manuipulation
  behs[, Datetime_behavior_starts := as.POSIXct(Datetime_behavior_starts, format = "%m/%d/%Y %H:%M:%S", tz = "UTC")]
  behs[, Datetime_behavior_ends   := as.POSIXct(Datetime_behavior_ends,   format = "%m/%d/%Y %H:%M:%S", tz = "UTC")]
  accel[, Datetime := as.POSIXct(Datetime, tz = "UTC")]
  
  # this is what they'll goin by
  setkey(behs, Bear, Datetime_behavior_starts, Datetime_behavior_ends)
  
  # join them togetehr based on the datetimes
  accel_beh <- foverlaps(
    accel[, .(Bear, Datetime, Int_aX, Int_aY, Int_aZ, end = Datetime)],
    behs[, .(Bear, Datetime_behavior_starts, Datetime_behavior_ends, Behavior)],
    by.x = c("Bear", "Datetime", "end"),
    by.y = c("Bear", "Datetime_behavior_starts", "Datetime_behavior_ends"),
    type = "within",
    nomatch = NULL
  )
  
  # format the labelled data
  fomatted_accel_beh <- accel_beh %>%
    rename(Time = Datetime,
           X = Int_aX,
           Y = Int_aY,
           Z = Int_aZ,
           ID = Bear,
           Activity = Behavior) %>%
    select(ID, Time, Activity, X, Y, Z)
  
  # save that
  fwrite(fomatted_accel_beh, file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
  
  # and save the remainder unlabelled data too
  accel_unlabelled <- accel[!accel_beh, on = .(Bear, Datetime)]
  accel_unlabelled <- accel_unlabelled %>%
    rename(Time = Datetime,
           X = Int_aX,
           Y = Int_aY,
           Z = Int_aZ,
           ID = Bear) %>%
    select(!Wetdry)
  fwrite(accel_unlabelled, file.path(base_path, "Data", species, "Formatted_unlabelled_data.csv"))
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
