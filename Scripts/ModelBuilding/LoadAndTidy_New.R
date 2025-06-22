
# Load in the data and tidy it to standard format -------------------------

if(file.exists(file.path(base_path, "Data", "CleanLabelledData.csv"))){
  data <- fread(file.path(base_path, "Data", "CleanLabelledData.csv"))
} else {
  data <- fread(file.path(base_path, "Data", "FinalTrainingData.csv")) # data Gabby gave me
  data <- data %>% rename(Activity = activity,
                          Time = time,
                          Accelerometer.X = X_accel,
                          Accelerometer.Y = Y_accel,
                          Accelerometer.Z = Z_accel,
                          Gyroscope.X = X_gyro,
                          Gyroscope.Y = Y_gyro,
                          Gyroscope.Z = Z_gyro
  )
  # elsa and meeka were collected at 100Hz and all the others were 50 Hz
  ElsaMeekadata <- data %>%
    filter(ID %in% c("Meeka", "Elsa")) %>%
    mutate(rownum = row_number()) %>%
    filter(rownum %% 2 == 1) %>%
    select(-rownum)
  
  Otherdata <- data %>% filter(!ID %in% c('Elsa', 'Meeka'))
  
  data <- rbind(ElsaMeekadata, Otherdata)
  
  fwrite(data, file.path(base_path, "Data", "CleanLabelledData.csv"))
}
