# Formatting the echidna data ---------------------------------------------

library(data.table)
library(dplyr)
library(stringr)
library(R.matlab)

sample_rate <- 10

# Get the files out of matlab ---------------------------------------------
input_dir <- "R:/FSHEE/Science/Unsupervised-Accel/Echidna data/echidna analysis" # they are stored here
output_dir <- "R:/FSHEE/Science/Unsupervised-Accel/Echidna data/Raw_data"

sure <- FALSE
# this takes FOREVER TO DO so be sure
if (sure == TRUE){
  mat_files <- list.files(input_dir, pattern = "\\.mat$", full.names = TRUE)
  file <- mat_files[64]
  for (file in mat_files) {
    data <- readMat(file)
    if ("Time.Acc.Temp.Activity.Mat.Scored" %in% names(data)) {
      df <- data[["Time.Acc.Temp.Activity.Mat.Scored"]]
      if (is.matrix(df) || is.data.frame(df)) {
        out_file <- file.path(output_dir,
                              paste0(tools::file_path_sans_ext(basename(file)), "_Extracted.csv"))
        write.csv(df, out_file, row.names = FALSE)
      }
    }
  }
}

# Format the non-aggregate ones together ----------------------------------
if(!file.exists(file.path(output_dir, "Formatted_all_data.csv"))){
  files <- list.files(output_dir, pattern = "\\corrected_Scored_Extracted.csv$", full.names = TRUE)
  
  data <- lapply(files, function(x){
    df <- fread(x)
    df$ID <- str_split(basename(x), pattern = "_")[[1]][1]
    
    df <- df %>%
      select(V1, V2, V3, V4, V13, ID) %>%
      rename(Time = V1,
             X = V2,
             Y = V3,
             Z = V4,
             Activity = V13)
  })
  
  data <- bind_rows(data)
  fwrite(data, file.path(output_dir, "Formatted_all_data.csv"))
  
  # Separate labelled and unlabelled data -----------------------------------
  labelled_data <- data %>% filter(!Activity == "0")
  fwrite(labelled_data, file.path(output_dir, "Formatted_raw_data.csv"))
  unlabelled_data <- data %>% filter(Activity == "0") %>% select(!Activity)
  fwrite(unlabelled_data, file.path(output_dir, "Formatted_unlabelled_data.csv"))
}

# Generate the features ---------------------------------------------------
if (file.exists(file.path(base_path, "Data", species, "Feature_data.csv"))){
  print("training features already generated")
} else {
  
  data1 <- fread(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
  
  generated_features <- list()
  for (id in unique(data1$ID)){
    data <- data1 %>% 
      filter(ID == id) %>% 
      as.data.table()
    
    feature_data <- processDataPerID(data, 
                                     features_type = c("timeseries", "statistical"), 
                                     window_length = 2, # to give it more data to work with 
                                     sample_rate = sample_rate, 
                                     overlap_percent = 10)
    
    generated_features[[id]] <- feature_data
  }
  generated_features_df <- bind_rows(generated_features)
  fwrite(generated_features_df, file.path(base_path, "Data", species, "Feature_data.csv"))
}


