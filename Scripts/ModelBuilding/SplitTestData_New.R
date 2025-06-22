
# Split out test data -----------------------------------------------------

if(file.exists(file.path(base_path, "Data", "RawOtherData.csv"))){
  fread(file.path(base_path, "Data", "RawOtherData.csv"))
} else {
  data <- fread(file.path(base_path, "Data", "CleanLabelledData.csv"))
  
  # Split data per individual and activity: last 20% as test, remaining 80% as training
  sig_data <- data %>% filter(ID %in% sig_individuals) # those with a lot of data
  gen_data <- data %>% filter(!ID %in% sig_individuals)
  
  # Split per group (ID and activty)
  split_sig_data <- sig_data %>%
    group_by(ID, Activity) %>%
    arrange(ID, Activity, row_number()) %>%  # Ensure consistent ordering within groups
    mutate(
      row_idx = row_number(),         # Get row index within each group
      total_rows = n()                # Total rows per group
    ) %>%
    mutate(
      is_test = row_idx > floor(0.8 * total_rows) # Define test rows
    ) %>%
    ungroup()
  
  # Separate into training and testing
  other_data <- split_sig_data %>%
    filter(!is_test) %>%
    select(-row_idx, -total_rows, -is_test)  # Drop helper columns
  
  test_data <- split_sig_data %>%
    filter(is_test) %>%
    select(-row_idx, -total_rows, -is_test)
  
  # Write the output files
  fwrite(other_data, file.path(base_path, "Data", "RawOtherData.csv"))
  fwrite(test_data, file.path(base_path, "Data", "RawTestData.csv"))
  fwrite(gen_data, file.path(base_path, "Data", "RawGeneralisationData.csv"))
}