# I processed all the datasets before I realised I needed to update the behavioural labels
# rather than repeat all that data provessing, I will just update the feature labels
# this is the script for that
# Normally this would be done as part of the data processing... which is why I wrote over the original labels 

# Figuring out which species should be regrouped --------------------------
all_species <- basename(list.dirs(file.path(base_path, "Data"), recursive = FALSE))

for (species in all_species){
  print(species)
  dat <- fread(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
  print(length(unique(dat$Activity)))
  print(unique(dat$Activity))
}

# Defining the regrouping -------------------------------------------------
# filled in the excel sheet with the old labels and the new labels based on the paper
# and logic... keeping notes in the associated txt file for reproducibility

# Doing the regrouping ----------------------------------------------------
activity_groupings <- fread(file.path(base_path, "Data/ActivityGroupings.csv"))
regrouped_species <- unique(activity_groupings$Dataset)

for (species in regrouped_species){
  
  print(species)
  regrouping <- activity_groupings %>% dplyr::filter(Dataset == species)
  
  # files to change
  feat_files <- list.files(file.path(base_path, "Data", species), pattern = "Feature_data.csv", full.names = TRUE)
  samp_files <- list.files(file.path(base_path, "Data", species), pattern = "Formatted_raw_data.csv", full.names = TRUE)
  files <- c(feat_files, samp_files)
  
  lapply(files, function(x){
    dat <- fread(x) %>%
      mutate(Activity = as.character(Activity)) %>%
      left_join(regrouping, by = c("Activity" = "DatasetActivity")) %>%
      mutate(Activity = coalesce(UpdatedActivity, Activity)) %>%
      select(-UpdatedActivity, -PaperActivity, -Dataset) %>%
      dplyr::filter(!Activity == "Remove")
    fwrite(dat, x)
    
  })
}
