
# COme back and do most of it later ---------------------------------------

data <- fread(file.path(base_path, "Data", species, "Raw_data_formatted.csv"))

data <- data %>% select(-EndTime, -group)
# and now make all of them but the labels numeric
numeric_data <- data %>%
  mutate(across(
    .cols = -c(Activity, ID, Time),
    .fns = ~ as.numeric(.)
  ))

fwrite(numeric_data, file.path(base_path, "Data", species, "Feature_data.csv"))
