# Formatting the squirrel data --------------------------------------------
# another nice and easy one

# read in the data
sample_rate <- 1

if(!file.exists(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))){
    
  data <- fread(file.path(base_path, "Data", species, "Studd_2019.csv"))
  
  data <- data %>%
    select(TIME, BEHAV, X, Y, Z, LCOLOUR, RCOLOUR) %>%
    mutate(ID = paste0(LCOLOUR, RCOLOUR)) %>%
    rename(Time = TIME,
           Activity = BEHAV) %>%
    select(!c(LCOLOUR, RCOLOUR)) 
  fwrite(data, file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
}
