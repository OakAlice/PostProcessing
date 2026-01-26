# formatting the goat data ------------------------------------------------

sample_rate <- 5

if (file.exists(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))){
  print("data already formatted")
} else {
  
  files <- list.files(file.path(base_path, "Data", species, "raw"), full.names = TRUE)
  data <- lapply(files, function(x){
    df <- fread(x)
    
    # combine the behaviours
    df <- df %>%
      mutate(
        Activity = case_when(
          !is.na(feeding_behav_data_goat) ~ feeding_behav_data_goat,
          !is.na(other_behav_data_goat)   ~ other_behav_data_goat,
          !is.na(social_behav_data_goat)  ~ social_behav_data_goat,
          TRUE                            ~ position_behav_data_goat
        )
      )
    df$Activity <- gsub(pattern = "NA", "", df$Activity)
    # there are some that seem to be typos I'm going to add them together
    df$Activity[df$Activity == "lyingd"] <- "lying"
    df$Activity[df$Activity == "standingp"] <- "standing"
    df$Activity[df$Activity == "othero"] <- "other"
    df$Activity[df$Activity == "otherf"] <- "other"
    df$Activity[df$Activity == "nonef"] <- NA
    df$Activity[df$Activity == ""] <- NA
    
    ID <- str_split(basename(x), "_")[[1]][3]
    df$ID <- gsub(".csv", "", ID)
    
    return(df)
  })
  
  data <- bind_rows(data)
  data <- data %>%
    rename(Time = TIME,
           X = ACCx,
           Y = ACCy,
           Z = ACCz) %>%
    select(ID, Time, Activity, X, Y, Z) %>%
    na.omit() %>%
    group_by(ID, Activity) %>%
    arrange(Time) %>%
    ungroup() %>%
    arrange(ID, Time)
  
  fwrite(data, file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
}

