# Ecology example ---------------------------------------------------------
# Case study with an ecological example.
if(!file.exists(file.path(base_path, "CaseStudy", species, paste0("Final_model.rds")))){

  # Load in the hyperparameters from the 3 optimised models -----------------
  previous_models <- list.files(file.path(base_path, "Data", species), pattern = ".rds", full.names = TRUE)
  HP <- lapply(previous_models, function(x){
    model <- readRDS(x)
    mtry <- model$mtry
    num_trees <- model$num.trees
    max_depth <- model$max.depth
    error <- model$prediction.error
    
    HPs <- c(mtry, num_trees, max_depth, error)
    HPs
  })
  HP <- rbindlist(lapply(HP, as.list), use.names = FALSE)[
    , c("mtry", "num_trees", "max_depth", "error") := .SD
  ][, .SD, .SDcols = c("mtry", "num_trees", "max_depth", "error")]
  
  # select HPs
  # TODO: Make this an automatic selection
  best_mtry <- HP$mtry[HP$error == min(HP$error)]
  best_num_trees <- HP$num_trees[HP$error == min(HP$error)]
  best_max_depth <- HP$max_depth[HP$error == min(HP$error)]
  
  # Train a model on all the labelled data ----------------------------------
  labelled_data <- as.data.table(fread(file.path(base_path, "Data", species, "Feature_data.csv")))
  clean_cols <- removeBadFeatures(labelled_data, var_threshold = 0.3, corr_threshold = 0.9)
  training_data <- labelled_data %>%
    select(c(!!!syms(clean_cols), "Activity")) %>%
    na.omit() %>%
    mutate(Activity = as.factor(Activity))
  
  # weight by class frequency
  class_freq <- table(training_data$Activity)
  class_weights <- 1 / class_freq
  class_weights <- class_weights / sum(class_weights)
  weight <- class_weights[training_data$Activity]
  
  # generate the model
  RF_model <- ranger(
    dependent.variable.name = "Activity",
    data = training_data,
    num.trees = best_num_trees,
    mtry = best_mtry,
    max.depth = best_max_depth,
    classification = TRUE,
    probability = TRUE,
    importance = "impurity",
    case.weights = weight
  )
  
  prediction_error <- RF_model$prediction.error
  saveRDS(RF_model, file.path(base_path, "CaseStudy", species, paste0("Final_model.rds")))
} else {
  # load in the model
  print("already generated -- loading now...")
  RF_model <- readRDS(file.path(base_path, "CaseStudy", species, paste0("Final_model.rds")))
}

# Extract the features that were used -------------------------------------
all_good_features <- RF_model$forest$independent.variable.names

# identify which of our features we are going to need to call by looking at the ones we have
# remove the axis calls from the specific features
needed_features <- all_good_features[grepl("_(X|Y|Z)$", all_good_features)]
needed_features <- unique(sub("_(X|Y|Z)", "", needed_features))
needed_features2 <- all_good_features[grepl("^Accel\\.(X|Y|Z)", all_good_features)]
needed_features2 <- unique(sub("^Accel\\.(X|Y|Z)_", "", needed_features2))
# list all of them together
needed_features <- c(needed_features, needed_features2)

# now determine which of the tsfeatures calls we need to make
# firstly I mapped each of the outputs back to the original inputs
# I did this by manually calling each of the left options and seeing what it created (right)
features_mapping = list(
  "acf_features" = c("x_acf1", "x_acf10", "diff1_acf1", "diff1_acf10", "diff2_acf1", "diff2_acf10"),
  "arch_stat" = c("ARCH.LM"),
  "autocorr_features" = c("embed2_incircle_1", "embed2_incircle_2", "ac_9", "firstmin_ac", "trev_num", "motiftwo_entro3", "walker_propcross"),
  "crossing_points" = c("crossing_points"),
  "dist_features" = c("histogram_mode_10", "outlierinclude_mdrmd"),
  "entropy" = c("entropy"),
  "firstzero_ac" = c("firstzero_ac"),
  "flat_spots" = c("flat_spots"),
  "heterogeneity" = c("arch_acf", "garch_acf", "arch_r2", "garch_r2"),
  "hw_parameters" = c("alpha", "beta", "gamma"),
  "hurst" = c("hurst"),
  "lumpiness" = c("lumpiness"),
  "stability" = c("stability"),
  "max_level_shift" = c("max_level_shift", "time_level_shift"),
  "max_var_shift" = c("max_var_shift", "time_var_shift"),
  "max_kl_shift" = c("max_kl_shift", "time_kl_shift"),
  "nonlinearity" = c("nonlinearity"),
  "pacf_features" = c("x_pacf5", "diff1x_pacf5", "diff2x_pacf5"),
  "pred_features" = c("localsimple_mean1", "localsimple_lfitac", "sampen_first"),
  "scal_features" = c("fluctanal_prop_r1"),
  "station_features" = c("std1st_der", "spreadrandomlocal_meantaul_50", "spreadrandomlocal_meantaul_ac2"),
  "stl_features" = c("nperiods", "seasonal_period", "trend", "spike", "linearity", "curvature", "e_acf1", "e_acf10"),
  "unitroot_kpss" = c("unitroot_kpss"),
  "zero_proportion" = c("zero_proportion")
)

needed_groups <- names(features_mapping)[
  sapply(features_mapping, function(feature_list) any(feature_list %in% needed_features))
]
# therefore, when I go to call "generate features" in the next step, I only have to call those.
# now generate them for each chunk

# for now I just have one individual but could expand out later
individuals <- list.dirs(file.path(base_path, "CaseStudy", species, "RawData"), full.names = TRUE, recursive = FALSE)
for (individual in individuals){
  # individual <- basename(individuals[3])
  individual <- basename(individual)
    
  # Process each of the files -----------------------------------------------
  unlabelled_files <- list.files(file.path(base_path, "CaseStudy", species, "RawData", individual), full.names = TRUE, pattern = ".csv", recursive = TRUE)
  # x <- unlabelled_files[3]
  
  # for each of the unlabelled files, generate features and then make predictions
  lapply(unlabelled_files, function(x){
    fname <- tools::file_path_sans_ext(basename(x))
    name <- fname # gsub("[0-9_]", "", fname)
    
    # generate features
    if (file.exists(file.path(base_path, "CaseStudy", species, "FeatureData", paste0(name, "_features.csv")))) {
      print(paste("feature data already generated for", name))
    } else {
      
      dat <- fread(x)
      dat <- dat[, 2:5] # first column is just a row number
      colnames(dat) <- c("Time", "X", "Y", "Z")
      dat$ID <- fname # for now give it the numeric as well
      
      # this only generates the specific features as used in the models
      #time_specific <- system.time({
      feature_data_specific <- generateSpecificFeatures(
          data = dat, 
          specific_features = all_good_features, 
          needed_groups = needed_groups,
          window_length = 2, 
          sample_rate = sample_rates[[species]], 
          overlap_percent = 0
        )
      print("chunk done")
  
      # write it as a temp file
      fwrite(feature_data_specific, file.path(base_path, "CaseStudy", species, "FeatureData", paste0(name, "_features.csv")))
    }
  })
}
    
  # Make predictions on each ------------------------------------------------
  unlabelled_features <- list.files(file.path(base_path, "CaseStudy", species, "FeatureData"), full.names = TRUE, pattern = ".csv", recursive = TRUE)
  predictions <- lapply(unlabelled_features, function(x){
    dat <- fread(x)
    
    if(species == "Sparkes_Koala"){
      # I messed up the feature column names oopsy # add the "Accel." back in
      colnames(dat) <- gsub("^(X_|Y_|Z_)", "Accel.\\1", colnames(dat))
    }
    # now select these features
    complete_cases <- dat %>%
      select(all_of(c(all_good_features, "ID", "Time"))) %>%
      na.omit()
    numeric_dat <- complete_cases %>%
      select(all_of(all_good_features)) %>%
      as.matrix()
    dat_metadata <- complete_cases %>%
      select(ID, Time)
    
    output <- predict(RF_model, data = numeric_dat, probability = TRUE)
    predictions <- output$predictions
    predicted_class <- colnames(predictions)[max.col(predictions, ties.method = "first")]
    predictions_df <- cbind(dat_metadata, predictions, predicted_class)
    predictions_df
  })
  predictions <- rbindlist(predictions)
  predictions$ID <- gsub("_[0-9]{3}$", "", predictions$ID)
  
  if(species == "Sparkes_Koala"){
    predictions$Time <- as.POSIXct((predictions$Time - 719529)*86400, origin = "1970-01-01", tz = "UTC")
  } else if (species == "Clemente_Echidna"){
    predictions <- predictions %>%
      group_by(ID) %>%
      arrange(Time, .by_group = TRUE) %>%
      mutate(
        # Start at arbitrary origin datetime
        Time = as.POSIXct("2025-01-01 00:00:00", tz = "UTC") + (Time - min(Time))
      ) %>%
      ungroup()
  }
  
  fwrite(predictions, file.path(base_path, "CaseStudy", species, "Predictions", "Original_predictions.csv"))
