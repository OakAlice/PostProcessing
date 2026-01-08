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
