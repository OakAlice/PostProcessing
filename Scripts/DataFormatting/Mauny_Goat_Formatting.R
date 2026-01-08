# formatting the goat data ------------------------------------------------

sample_rate <- 5

if (file.exists(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))){
  print("data already formatted")
} else {
  
  files <- list.files(file.path(base_path, "Data", species, "raw"), full.names = TRUE)
  data <- lapply(files, function(x){
    df <- fread(x)
    
    # combine the behaviours
    df[, (names(df)) := lapply(.SD, function(x) {
      x[x %in% c("nones", "noneo", "no", "nonef")] <- NA
      x
    })]
    
    # did this once to look at it
    df <- df %>%
       mutate(combo = paste0(feeding_behav_data_goat, position_behav_data_goat, social_behav_data_goat, other_behav_data_goat, disturb_behav_data_goat)) #%>%
    #   group_by(combo) %>%
    #   count()
    df$combo <- gsub(pattern = "NA", "", df$combo)
    # there are some that are so aimilar I'm going to add them together
    df$Activity <- df$combo
    df$Activity[df$combo == "ruminatinglyingd"] <- "ruminatinglying"
    df$Activity[df$combo == "lyingd"] <- "lying"
    df$Activity[df$combo == "standingp"] <- "standing"
    df$Activity[df$combo == "ruminatingstandingp"] <- "ruminatingstanding"
    
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
    select(ID, Time, Activity, X, Y, Z)
  
  fwrite(data, file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
}

