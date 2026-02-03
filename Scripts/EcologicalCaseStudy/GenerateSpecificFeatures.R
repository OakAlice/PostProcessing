# Mode
get_mode <- function(x) {
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}


# only do this code if the feature was requested by name ####
compute_if <- function(name, value, specific_features) {
  if (name %in% specific_features) value else NULL
}

# Function to generate only the specific features that are used in the identification model ####
generateSpecificFeatures <- function(data, specific_features, needed_groups, window_length, sample_rate, overlap_percent) {
  
  # Calculate window length and overlap
  samples_per_window <- window_length * sample_rate
  overlap_samples <- if (overlap_percent > 0) ((overlap_percent / 100) * samples_per_window) else 0
  num_windows <- ceiling((nrow(data) - overlap_samples) / (samples_per_window - overlap_samples))
  
  # Function to process each window for this specific ID
  process_window <- function(i) {
    start_index <- max(1, round((i - 1) * (samples_per_window - overlap_samples) + 1))
    end_index <- min(start_index + samples_per_window - 1, nrow(data))
    window_chunk <- data[start_index:end_index, ]
    
    # Initialize output features
    window_info <- data.table(Time = NA, ID = NA, Activity = NA)
    statistical_result <- data.table() 
    single_row_features <- data.table()  
    
    window_chunk <- setDT(window_chunk)
    
    for (axis in c("X", "Y", "Z")) {
      v <- window_chunk[[axis]]
      
      if (paste0("mean_", axis) %in% specific_features) {
        statistical_result[, (paste0("mean_", axis)) := mean(v, na.rm = TRUE)]}
      
      if (paste0("sd_", axis) %in% specific_features) {
        statistical_result[, (paste0("sd_", axis)) := sd(v, na.rm = TRUE)]}
      
      if (paste0("min_", axis) %in% specific_features) { 
        statistical_result[, (paste0("min_", axis)) := min(v, na.rm = TRUE)]}
      
      if (paste0("max_", axis) %in% specific_features) { 
        statistical_result[, (paste0("max_", axis)) := max(v, na.rm = TRUE)]}
      
      if (paste0("sk_", axis) %in% specific_features) { 
        statistical_result[, (paste0("sk_", axis)) := e1071::skewness(v, na.rm = TRUE)]}
      
      # define the possible fft variables
      fft_needed <- paste0(
        c("mean_mag_", "max_mag_", "total_power_", "peak_freq_"),
        axis
      )
      if (any(fft_needed %in% specific_features)) {
        fft <- extractFftFeatures(v, sample_rate)
        
        if (paste0("mean_mag_", axis) %in% specific_features)
          statistical_result[, (paste0("mean_mag_", axis)) := fft$Mean_Magnitude]
        
        if (paste0("max_mag_", axis) %in% specific_features)
          statistical_result[, (paste0("max_mag_", axis)) := fft$Max_Magnitude]
        
        if (paste0("total_power_", axis) %in% specific_features)
          statistical_result[, (paste0("total_power_", axis)) := fft$Total_Power]
        
        if (paste0("peak_freq_", axis) %in% specific_features)
          statistical_result[, (paste0("peak_freq_", axis)) := fft$Peak_Frequency]
      }
    }
    
    if ("SMA" %in% specific_features) { 
      statistical_result[, SMA := sum(rowSums(abs(window_chunk[, c("X", "Y", "Z"), with = FALSE]))) / nrow(window_chunk)]}
    
    ODBA <- rowSums(abs(window_chunk[, c("X", "Y", "Z"), with = FALSE]))
    if ("minODBA" %in% specific_features) { 
      statistical_result[, `:=`(minODBA = min(ODBA, na.rm = TRUE))]}
    if ("maxODBA" %in% specific_features) { 
      statistical_result[, `:=`(minODBA = max(ODBA, na.rm = TRUE))]}
    
    VDBA <- sqrt(rowSums(window_chunk[, c("X", "Y", "Z"), with = FALSE]^2))
    if ("minVDBA" %in% specific_features) { 
      statistical_result[, `:=`(minVDBA = min(VDBA, na.rm = TRUE))]}
    if ("maxVDBA" %in% specific_features) { 
      statistical_result[, `:=`(minVDBA = max(VDBA, na.rm = TRUE))]}
    
    # Part 2: Extract required timeseries features
    time_series_features <- list()
    ts_list <- list(
      X = window_chunk[["X"]],
      Y = window_chunk[["Y"]],
      Z = window_chunk[["Z"]]
    )
    
    # Loop through each feature and calculate it
    for (feature in needed_groups) {
      tryCatch({
        feature_values <- tsfeatures(
          tslist = ts_list,
          features = feature,
          scale = FALSE,
          multiprocess = TRUE
        )
        time_series_features[[feature]] <- feature_values
      }, error = function(e) {
        message("Skipping feature ", feature, " due to error: ", e$message)
      })
    }
    
    # Combine all features into a single tibble
    if (length(time_series_features) > 0) {
      time_series_features <- bind_cols(time_series_features)
    } else {
      time_series_features <- tibble()
    }
    
    if (nrow(time_series_features) > 0) {
      single_row_features <- time_series_features %>%
        mutate(axis = rep(c("X", "Y", "Z"), length.out = n())) %>%
        pivot_longer(cols = -axis, names_to = "feature", values_to = "value") %>%
        unite("feature_name", axis, feature, sep = "_") %>%
        pivot_wider(names_from = feature_name, values_from = value)
    } else {
      message("No rows in time_series_features. Returning empty tibble.")
      single_row_features <- tibble(matrix(NA, nrow = 1, ncol = length(unique(paste0(rep(c("X", "Y", "Z"), each = length(time_series_features)), "_", names(time_series_features))))))  # Fill with NAs
      colnames(single_row_features) <- unique(paste0(rep(c("X", "Y", "Z"), each = length(time_series_features)), "_", names(time_series_features)))  # Match the column names
    }
    
    if (nrow(window_chunk) > 0) {
      window_info <- window_chunk %>% 
        summarise(
          Time = first(Time),
          ID = first(ID),
          Activity = if ("Activity" %in% names(.)) {
            as.character(names(sort(table(Activity), decreasing = TRUE))[1])
          } else {
            NA
          }
        ) %>% 
        ungroup()
    }
    
    # Ensure that blank inputs are handled by replacing them with placeholders
    window_info <- if (is.null(window_info) || nrow(window_info) == 0) data.frame(matrix(NA, nrow = 1, ncol = 0)) else window_info
    single_row_features <- if (is.null(single_row_features) || nrow(single_row_features) == 0) data.frame(matrix(NA, nrow = 1, ncol = 0)) else single_row_features
    statistical_result <- if (is.null(statistical_result) || nrow(statistical_result) == 0) data.frame(matrix(NA, nrow = 1, ncol = 0)) else statistical_result
    
    # Combine the data frames
    combined_features <- cbind(window_info, single_row_features, statistical_result) %>%
      mutate(across(everything(), ~replace_na(., NA)))  # Ensure all columns are present
    
    return(combined_features)
  }
  
  # Use future_lapply to parallel process chunks of windows
  chunks <- split(
    seq_len(num_windows),
    ceiling(seq_len(num_windows) / 500)  # tune this
  )
  
  plan(multisession, workers = availableCores() - 1)
  
  window_features_list <- future_lapply(chunks, function(idx) {
    lapply(idx, process_window)
  })
  
  window_features_list <- unlist(window_features_list, recursive = FALSE)
  
  plan(sequential)
  
  # Combine all the windows for this ID into a single data frame
  features <- bind_rows(window_features_list)
  return(features)
}