# Formatting the cat data --------------------------------------------
# this paper was replication of Galea paper, so data already in format

# variables
sample_rate <- 30

if(!file.exists(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))){
    
  data <- fread(file.path(base_path, "Data", species, "Smit_Cat_Labelled.csv"))
  
  data <- data %>%
    rename(Time = datetime,
           X = Accelerometer.X,
           Y = Accelerometer.Y,
           Z = Accelerometer.Z) %>%
    select(ID, Time, Activity, X, Y, Z)
  
  fwrite(data, file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
}
