# Turtle Data H5 & csv -------------------------------------------------------
# Load in the required packages for dealing with h5 files --------------------

if(!file.exists(file.path(base_path, "Data", "Jeantet_Turtle/Formatted_raw_data.csv"))){



if (!requireNamespace("BiocManager", quietly = TRUE))
  install.packages("BiocManager")
BiocManager::install("rhdf5", force = TRUE)
# Source - https://stackoverflow.com/a/19486248
# Posted by Mike T, modified by community. See post 'Timeline' for change history
# Retrieved 2026-02-05, License - CC BY-SA 4.0
library(rhdf5)

# load in the raw data ------------------------------------------------------
raw_files <- list.files(
  path = "D:/LabelledDataSets/Jeantet_Turtle/raw",
  recursive = F,
  pattern = "\\.h5$",
  full.names = TRUE)

raw_data <- lapply(raw_files, function(x){
  h5ls(x)
  acc <- h5read(x, "data")
  acc <- as.data.frame(t(acc))
  colnames(acc) <- c("X", "Y", "Z", "GX", "GY", "GZ", "Depth")
  acc$Id <- tools::file_path_sans_ext(basename(x)) 
  acc$Row_Number <- seq_len(nrow(acc))  
  acc
})
raw_data <- rbindlist(raw_data)

# behaviour files ---------------------------------------------------------
behaviors_files <- list.files(
  path = "D:/LabelledDataSets/Jeantet_Turtle/raw",
  recursive = TRUE,
  pattern = "\\.csv$",
  full.names = TRUE)

behaviors_data <- lapply(behaviors_files, function(file) {
  print(file)
  df <- read_csv(file, show_col_types = F)
  df <- df %>% 
    rowwise %>% 
    rename(V1 = colnames(df)) %>% 
    mutate(Stt_Time = str_split(V1, ";", simplify = T)[1],
           Stp_Time = str_split(V1, ";", simplify = T)[3],
           Activity = str_split(V1, ";", simplify = T)[5],
           Syc_Stt_Time = str_split(V1, ";", simplify = T)[8], # this is the time that has already been synchronised
           Syc_Stp_Time = str_split(V1, ";", simplify = T)[9]) %>% 
    select(-V1) %>%
    mutate( Id =
              gsub("Behaviors_", "", tools::file_path_sans_ext(basename(file))))
  return(df)
})
behaviors_data <- bind_rows(behaviors_data)

behaviors_data <- behaviors_data %>% 
  mutate(
    First_Row = as.numeric(Syc_Stt_Time)*20, # convert into row numbers so can be stitched
    Last_Row = as.numeric(Syc_Stp_Time)*20
  )

# bind them together ------------------------------------------------------
setDT(raw_data)
setDT(behaviors_data)
setkey(behaviors_data, Id, First_Row, Last_Row)

data <- behaviors_data [
  raw_data,
  on = . (
    Id,
    First_Row <= Row_Number,
    Last_Row >= Row_Number
  ),
  nomatch = 0,
  .(
    Id,
    Activity,
    X,
    Y,
    Z,
    GX,
    GY, 
    GZ,
    Row_Number,
    Stt_Time
  )
]

# clean up and set times --------------------------------------------------
data <- data %>% 
  arrange(Row_Number) %>% 
  mutate(
    change = as.integer(!is.na(lag(Stt_Time)) & Stt_Time != lag(Stt_Time)),
    group_id = cumsum(change)
  ) %>%
  group_by(group_id) %>%
  mutate(
    cumchange = row_number() / 20,
    Date = str_split(Id, "_", simplify = TRUE)[, 2]
  ) %>%
  mutate(
    Updated_Time = as.POSIXct(
      paste(Date, Stt_Time),
      format = "%d-%m-%Y %H:%M:%S",
      tz = "UTC"
    ),
    Updated_Time = Updated_Time + lubridate::seconds(cumchange),
    Id = str_split(Id, "_", simplify = TRUE)[, 1]
  ) %>% 
  ungroup()

data <- data %>% 
  select(Id, Activity, X, Y, Z, GX, GY, GZ, Updated_Time) %>% 
  rename(ID = Id,
         Time = Updated_Time)

# Updating the behavioural labels -----------------------------------------
activity_groupings <- fread(file.path(base_path, "Data/ActivityGroupings.csv"))
regrouping <- activity_groupings %>% dplyr::filter(Dataset == "Jeantet_Turtle")
# change
data <- data %>%
      mutate(Activity = as.character(Activity)) %>%
      left_join(regrouping, by = c("Activity" = "DatasetActivity")) %>%
      mutate(Activity = coalesce(UpdatedActivity, Activity)) %>%
      select(-UpdatedActivity, -PaperActivity, -Dataset)

# Sequencing --------------------------------------------------------------
data <- data %>%
  group_by(ID) %>%
  arrange(Time) %>%
  mutate(time_diff = difftime(Time, data.table::shift(Time)), # had to define package or errored
         break_point = ifelse(time_diff > 2 | time_diff < 0 , 1, 0),
         break_point = replace_na(break_point, 0),
         sequence = cumsum(break_point)) %>%
  select(-break_point, -time_diff)


fwrite(data, file.path(base_path, "Data", "Jeantet_Turtle/Formatted_raw_data.csv"))   
} else {
  print("already formatted")
}