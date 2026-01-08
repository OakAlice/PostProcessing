# Formatting the pangolin data --------------------------------------------
sample_rate <- 50

if (file.exists(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))){
  print("data already formatted")
} else {
  
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
}
