
# Hyperparameter Optimisation ---------------------------------------------

# remove redundant and NA columns
removeBadFeatures <- function(feature_data, var_threshold, corr_threshold) {
  
  # Step 1: Calculate variance for numeric columns
  numeric_columns <- feature_data[, .SD, .SDcols = !names(feature_data) %in% c("Activity", "ID")]
  variances <- numeric_columns[, lapply(.SD, var, na.rm = TRUE)]
  selected_columns <- names(variances)[!is.na(variances) & variances > var_threshold]
  
  # Step 2: Remove highly correlated features
  numeric_columns <- numeric_columns[, ..selected_columns]
  corr_matrix <- cor(numeric_columns, use = "pairwise.complete.obs")
  high_corr <- findCorrelation(corr_matrix, cutoff = corr_threshold)
  remaining_features <- setdiff(names(numeric_columns), names(numeric_columns)[high_corr])
  
  return(remaining_features)
}

# main call that splits data, generates function, and validates
RFModelOptimisation <- function(feature_data, data_split, number_trees, mtry, max_depth){
  
    # remove bad features
    feature_data <- as.data.table(feature_data)
    
    clean_cols <- removeBadFeatures(feature_data, var_threshold = 0.5, corr_threshold = 0.9)
    clean_feature_data <- feature_data %>%
      select(c(!!!syms(clean_cols), "Activity", "ID")) %>% 
      select(-Time) %>%
      na.omit()
  
    f1_scores <- list()  # List to store F1-scores
    
    # Repeat the process 3 times
    for (i in 1:3) {
      message(i)
      flush.console()
      
      
      if (data_split == "chronological"){
        tryCatch({
          #Create training and validation data, split chronologically 
          split_feature_data <- clean_feature_data %>%
            group_by(ID, Activity) %>%
            arrange(ID, Activity, row_number()) %>%  # Ensure consistent ordering within groups
            mutate(
              row_idx = row_number(),         # Get row index within each group
              total_rows = n()                # Total rows per group
            ) %>%
            mutate(
              is_test = row_idx > floor(0.8 * total_rows) # Define test rows (20%)
            ) %>%
            ungroup()
  
          # Separate into training and testing
          training_data <- split_feature_data %>%
            filter(!is_test) %>%
            select(-c(row_idx, total_rows, is_test, ID, Time))
          training_data$Activity <- as.factor(training_data$Activity)
          
          validation_data <- split_feature_data %>%
            filter(is_test) %>%
            select(-row_idx, -total_rows, -is_test, -ID, -Time)
   
          message("data split")
          flush.console()
          
        }, error = function(e) {
          message("Error in data splitting: ", e$message)
        })
        
      } else { # based on individual
        
        tryCatch({
          #Create training and validation data, split by ID
          test_IDs <- sample(unique(clean_feature_data$ID), 0.2*length(unique(clean_feature_data$ID)))
          
          validation_data <- clean_feature_data %>% filter(ID %in% test_IDs)
          training_data <- clean_feature_data %>% filter(!ID %in% test_IDs)                      
          
          # Separate into training and testing
          training_data <- training_data %>%
            select(-c(ID)) %>%
            mutate(Activity = as.factor(Activity))
          
          validation_data <- validation_data %>%
            select(-c(ID)) %>%
            mutate(Activity = as.factor(Activity))
          
          message("data split")
          flush.console()
          
        }, error = function(e) {
          message("Error in data splitting: ", e$message)
        })
      }
      
      # Train RF model
      tryCatch({
        
        RF_model <- ranger(
          dependent.variable.name = "Activity",
          data = training_data,
          num.trees = number_trees,
          mtry = mtry,
          max.depth = max_depth,
          classification = TRUE,
          importance = "impurity"
        )
        
        message("model trained")
        flush.console()
        
      }, error = function(e) {
        message("Error in RF training: ", e$message)
        stop()
      })
      
      #### Validate the model
      tryCatch({
        numeric_validation_data <- as.matrix(validation_data[, !names(validation_data) %in% c("Activity"), with = FALSE])
        ground_truth_labels <- validation_data$Activity
        
        if (anyNA(numeric_validation_data)) {
          message("Validation data contains missing values!")
          flush.console()
        }
        
        numeric_validation_data <- as.data.frame(numeric_validation_data)
        predictions <- predict(RF_model, data = numeric_validation_data)
        predicted_classes <- predictions$predictions
        
        message("predictions made")
        flush.console()
        
      }, error = function(e) {
        message("Error in making predictions: ", e$message)
        flush.console()
        stop()
      })
      
      # Confusion matrix and performance metrics
      # convert to factors with the same levels
      all_classes <- sort(union(unique(predicted_classes), unique(ground_truth_labels)))
      predicted_classes <- factor(unlist(predicted_classes), levels = all_classes)
      ground_truth_labels <- factor(ground_truth_labels, levels = all_classes)
      
      # make a confusion matrix
      confusion_matrix <- table(predicted_classes, ground_truth_labels)
      
      # Handling mismatched dimensions
      all_classes <- sort(union(colnames(confusion_matrix), rownames(confusion_matrix)))
      conf_matrix_padded <- matrix(0, 
                                   nrow = length(all_classes), 
                                   ncol = length(all_classes),
                                   dimnames = list(all_classes, all_classes))
      conf_matrix_padded[rownames(confusion_matrix), colnames(confusion_matrix)] <- confusion_matrix
      
      # Calculate F1 scores
      confusion_mtx <- confusionMatrix(conf_matrix_padded)
      f1 <- confusion_mtx$byClass[, "F1"]
      support <- rowSums(confusion_mtx$table)  # True instances per class
      
      # Compute weighted F1 (rather than the macro which is what I was doing before)
      weighted_f1 <- weighted.mean(f1, w = support, na.rm = TRUE)
      
      # Store the F1 score
      f1_scores[[i]] <- weighted_f1
    }
    
    #### Calculate average F1-scors
    average_macro_f1 <- mean(unlist(f1_scores), na.rm = TRUE)
    
    # no preds for this one
    return(list(Score = average_macro_f1, Pred = NA))
}