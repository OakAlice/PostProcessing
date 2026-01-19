# Formatting for the rattlesnake data -------------------------------------

if(!file.exists(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))){
  dat <- fread(file.path(base_path, "Data", species, "raw", "CRAT_ACT_TrainingDataset_2016-2018IMRS.csv")) %>%
    mutate(Time = as.POSIXct(paste(Date, Time), format = "%m/%d/%y %H:%M:%S", tz = "UTC")) %>%
    rename(ID = TagID,
           Y = Ydyn,
           Activity = Behavior) %>%
    select("ID", "Time", "Activity", "X", "Y", "Z")
  fwrite(dat, file.path(base_path, "Data", species, "Formatted_raw_data.csv"))  
  
} else {
  print("file already exists")
}

  