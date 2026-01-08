# Vehkaoja_Dog ------------------------------------------------------------
# there is no time in this data (nor in the original data)
# therefore for "time" I've just grouped it into tests, presuming that everything in the test is continuous 
sample_rate <- 100

if(!file.exists(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))){
  
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
}
  