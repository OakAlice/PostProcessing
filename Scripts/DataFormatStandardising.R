# Loading and prepping the data -------------------------------------------
# Once the predictions have been generated (in other projects), I standardise their output

# at the moment this is really simple, but I can imagine that there may be data that I didn't create
# which might have a really different format... so just leaving space for this to become more complex

# List the files and read them all together
files <- list.files(file.path(base_path, "Data", "RawPredictions", species), recursive = TRUE, full.names = TRUE)

data <- lapply(files, fread)
data_table <- bind_rows(data) %>% 
  select(Time, predicted_classes, ID)

# save this back to the standardised location
fwrite(data_table, file.path(base_path, "Data", "StandardisedPredictions", paste0(species, "_raw_standardised.csv")))
