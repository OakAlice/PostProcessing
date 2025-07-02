# Mauny Goat Data -------------------------------------------------------
sample_rate <- 5



# Determining behavioural categories --------------------------------------
# has been labelled with multiple categories simultaneously. 
df <- fread(list.files(file.path(base_path, "Data", species, "raw"), full.names = TRUE)[1])

df[, (names(df)) := lapply(.SD, function(x) {
  x[x %in% c("nones", "noneo", "no", "nonef")] <- NA
  x
})]
unique_behs <- df %>% 
  mutate(combo = paste(feeding_behav_data_goat, position_behav_data_goat, social_behav_data_goat, other_behav_data_goat, disturb_behav_data_goat, sep = "_")) %>%
  group_by(combo) %>%
  count()



# Load them all in --------------------------------------------------------
files <- list.files(file.path(base_path, "Data", species, "raw"), full.names = TRUE)

data <- lapply(files, function(x){
  df <- fread(x)
  
})
