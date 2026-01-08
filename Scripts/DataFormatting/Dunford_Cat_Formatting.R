# Formatting the cat data -------------------------------------------------

sample_rate <- 40

if(!file.exists(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))){

  file <- list.files(file.path(base_path, "Data", species), recursive = TRUE, full.names = TRUE)

  df <- read.csv(file)
  
  df <- df %>%
    rename(X = AccX,
           Y = AccY,
           Z = AccZ,
           Activity = Behaviour)
  
  # save this 
  fwrite(df, file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
} else {
  print("data already created")
}
