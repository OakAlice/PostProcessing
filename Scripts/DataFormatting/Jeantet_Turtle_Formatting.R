# Jeantet Turtle formatting -----------------------------------------------


# havent finished this



# Read in the behavioural labels ------------------------------------------
label_data_files <- list.files(file.path(base_path, "Data", species), pattern = ".csv", full.name = TRUE, recursive = TRUE)
label_data <- lapply(label_data_files, function(x){
  data <- fread(x)
  data$ID <- basename(x)
  
  data <- data %>%
    rename(Time_Begin = HeureDeb,
           Time_End = HeureFin,
           
           )
    
  
  
  return(data)
})
label_data <- bind_rows(label_data)

