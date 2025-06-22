
# Function to generate specific features ----------------------------------

# Optimized main function
generateSpecificFeatures <- function(window_length, sample_rate, overlap_percent, raw_data, specific_features) {
  samples_per_window <- window_length * sample_rate
  overlap_samples <- if (overlap_percent > 0) ((overlap_percent / 100) * samples_per_window) else 0
  num_windows <- ceiling((nrow(raw_data) - overlap_samples) / (samples_per_window - overlap_samples))
  
  # Precompute window indices
  start_indices <- seq(1, by = (samples_per_window - overlap_samples), length.out = num_windows)
  end_indices <- pmin(start_indices + samples_per_window - 1, nrow(raw_data))
  
  # Process each window in parallel
  plan(multisession, workers = parallel::detectCores() - 1)
  window_features_list <- future_lapply(seq_along(start_indices), function(i) {
    window_chunk <- raw_data[start_indices[i]:end_indices[i], ]
    
    window_info <- data.table(Time = first(window_chunk$Time),
                              ID = first(window_chunk$ID),
                              Activity = if ("Activity" %in% names(window_chunk)) {
                                as.character(names(sort(table(window_chunk$Activity), decreasing = TRUE))[1])
                              } else { NA })
    
    statistical_features <- generateSpecificStatisticalFeatures(window_chunk, sample_rate, specific_features)
    time_series_features <- generateSpecificTsFeatures(window_chunk, specific_features)
    
    combined_features <- cbind(window_info, time_series_features, statistical_features)
    return(combined_features)
  })
  
  features <- rbindlist(window_features_list, fill = TRUE)
  return(features)
}

# Optimized Time Series Feature Extraction
generateSpecificTsFeatures <- function(data, specific_features) {
  ts_list <- list(
    X = data[["Accelerometer.X"]],
    Y = data[["Accelerometer.Y"]],
    Z = data[["Accelerometer.Z"]]
  )
  
  
  # fix this at some later point
  # feature_mapping_dt <- data.table(
  #   output_feature = c("x_acf_1", "x_acf10", "firstmin_ac", "crossing_points", "firstzero_ac", 
  #                      "flat_spots", "time_level_shift", "time_var_shift", 
  #                      "max_kl_shift", "time_kl_shift", "nonlinearity", 
  #                      "localsimple_mean1", "localsimple_lfitac", 
  #                      "spreadrandomlocal_meantaul_ac2"),
  #   tsfeatures_name = c("acf_features", "arch_stat", "autocorr_features", "crossing_points", "dist_features",
  #                       "entropy", "firstzero_ac", "flat_spots", "heterogeneity", "hw_parameters", "hurst",
  #                       "lumpiness", "stability", "max_level_shift", "max_var_shift", "max_kl_shift", 
  #                       "nonlinearity", "pacf_features", "pred_features", "scal_features", "station_features", 
  #                       "stl_features", "unitroot_kpss", "zero_proportion")
  # )
  # 
  # base_feature_names <- unique(gsub("Accel.[XYZ]_", "", specific_features))
  # features_to_generate <- feature_mapping_dt[output_feature %in% base_feature_names, unique(tsfeatures_name)]
  
  features_to_generate <- c(
    "acf_features", "arch_stat", "autocorr_features", "crossing_points", "dist_features",
  "entropy", "firstzero_ac", "flat_spots", "heterogeneity", "hw_parameters", "hurst",
  "lumpiness", "stability", "max_level_shift", "max_var_shift", "max_kl_shift", 
  "nonlinearity", "pacf_features", "pred_features", "scal_features", "station_features", 
  "stl_features", "unitroot_kpss", "zero_proportion"
  )
  
  # Initialize empty list for results
  time_series_features_list <- list()
  
  # Process each axis separately
  for (axis in names(ts_list)) {
    ts_data <- tsfeatures(ts_list[[axis]], features = features_to_generate, scale = FALSE, multiprocess = TRUE)
    
    setnames(ts_data, old = names(ts_data), new = paste0("Accel.", axis, "_", names(ts_data)))

    time_series_features_list[[axis]] <- ts_data
  }
  
  # Flatten into a single row
  time_series_features <- cbind(time_series_features_list$X, time_series_features_list$Y, time_series_features_list$Z)
  
  return(time_series_features)
}


# Optimized Statistical Feature Extraction
generateSpecificStatisticalFeatures <- function(window_chunk, down_Hz, specific_features) {
  setDT(window_chunk)  # Convert to data.table for efficiency
  result <- data.table()  # Initialize result container
  
  # Extract base feature names and their corresponding axes
  requested_features <- unique(gsub("_(Accelerometer|Gyroscope)\\.[XYZ]", "", specific_features))
  
  # Iterate over each axis
  for (axis in c("Accelerometer.X", "Accelerometer.Y", "Accelerometer.Z", "Gyroscope.X", "Gyroscope.Y", "Gyroscope.Z")) {
    
    axis_data <- window_chunk[[axis]]
    
    # Compute statistics conditionally
    if ("mean" %in% requested_features) {
      set(result, j = paste0("mean_", axis), value = mean(axis_data, na.rm = TRUE))
    }
    if ("max" %in% requested_features) {
      set(result, j = paste0("max_", axis), value = max(axis_data, na.rm = TRUE))
    }
    if ("min" %in% requested_features) {
      set(result, j = paste0("min_", axis), value = min(axis_data, na.rm = TRUE))
    }
    if ("sd" %in% requested_features) {
      set(result, j = paste0("sd_", axis), value = sd(axis_data, na.rm = TRUE))
    }
    if ("sk" %in% requested_features) {
      set(result, j = paste0("sk_", axis), value = e1071::skewness(axis_data, na.rm = TRUE))
    }
    
    # FFT features
    if (any(c("mean_mag", "max_mag", "total_power", "peak_freq") %in% requested_features)) {
      fft_features <- extractFftFeatures(axis_data, down_Hz)
      if ("mean_mag" %in% requested_features) {
        set(result, j = paste0("mean_mag_", axis), value = fft_features$Mean_Magnitude)
      }
      if ("max_mag" %in% requested_features) {
        set(result, j = paste0("max_mag_", axis), value = fft_features$Max_Magnitude)
      }
      if ("total_power" %in% requested_features) {
        set(result, j = paste0("total_power_", axis), value = fft_features$Total_Power)
      }
      if ("peak_freq" %in% requested_features) {
        set(result, j = paste0("peak_freq_", axis), value = fft_features$Peak_Frequency)
      }
    }
  }
  
  # Compute ODBA if required & VDBA always (as we use it as a proxy of energy)
    ODBA <- rowSums(abs(window_chunk[, .(Accelerometer.X, Accelerometer.Y, Accelerometer.Z)]))
    VDBA <- sqrt(rowSums(window_chunk[, .(Accelerometer.X, Accelerometer.Y, Accelerometer.Z)]^2))
    
    if ("minODBA" %in% requested_features) {
      set(result, j = "minODBA", value = min(ODBA, na.rm = TRUE))
    }
    if ("maxODBA" %in% requested_features) {
      set(result, j = "maxODBA", value = max(ODBA, na.rm = TRUE))
    }
    set(result, j = "minVDBA", value = min(VDBA, na.rm = TRUE))
    set(result, j = "maxVDBA", value = max(VDBA, na.rm = TRUE))
  
  return(result)
}


# Optimized FFT Feature Extraction
extractFftFeatures <- function(window_data, down_Hz) {
  n <- length(window_data)
  
  # Compute FFT
  fft_result <- fft(window_data)
  freq <- (0:(n/2 - 1)) * (down_Hz / n)
  magnitude <- abs(fft_result[1:(n/2)])
  
  list(
    Mean_Magnitude = mean(magnitude),
    Max_Magnitude = max(magnitude),
    Total_Power = sum(magnitude^2),
    Peak_Frequency = freq[which.max(magnitude)]
  )
}

