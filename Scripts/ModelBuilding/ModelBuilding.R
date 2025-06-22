# Designing a model -------------------------------------------------------

species <- "Vehkaoja_Dogs"

# Standardising the data from BEBE ----------------------------------------
# already these are already standardised, it doesn't work for my purposes
# therefore I need to reformat them
# load in the data
data <- fread(file.path(base_path, "Data", "MakeModelsAndPredictions", species, paste0(species, "_BEBE_formatted.csv")))


