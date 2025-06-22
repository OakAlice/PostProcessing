
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
RFModelOptimisation <- function(feature_data, number_trees, mtry, max_depth){
  
    # remove bad features
    feature_data <- as.data.table(feature_data)
    
    clean_cols <- removeBadFeatures(feature_data, var_threshold = 0.5, corr_threshold = 0.9)
    clean_feature_data <- feature_data %>%
      select(c(!!!syms(clean_cols), "Activity", "ID")) %>% 
      #select(-Time) %>%
      na.omit()
  
    f1_scores <- list()  # List to store F1-scores
    
    # Repeat the process 3 times
    for (i in 1:3) {
      message(i)
      flush.console()
      
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
      
      # Train RF model
      tryCatch({
        # RF training
        # RF_args <- list(
        #   x = as.matrix(training_data[, setdiff(names(training_data), "Activity"), with = FALSE]),
        #   y = as.factor(training_data$Activity),
        #   ntree = number_trees,
        #   class_weight = 'balanced',
        #   mtry = mtry,
        #   max_depth = max_depth
        # )
        # RF_model <- do.call(randomForest, RF_args)
        
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
        numeric_validation_data <- as.matrix(validation_data[, !names(validation_data) %in% c("Activity", "ID"), with = FALSE])
        ground_truth_labels <- validation_data$Activity
        
        if (anyNA(numeric_validation_data)) {
          message("Validation data contains missing values!")
          flush.console()
        }
        
        # Predict on validation data
        # predictions <- predict(RF_model, newdata = numeric_validation_data)
        
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
      macro_f1 <- mean(f1, na.rm = TRUE)
      
      # Store the F1 score
      f1_scores[[i]] <- macro_f1
    }
    
    #### Calculate average F1-score ####
    average_macro_f1 <- mean(unlist(f1_scores), na.rm = TRUE)
    
    return(list(Score = average_macro_f1, Pred = NA))
}

# Run the analysis --------------------------------------------------------

# define the bounds within which to search
bounds <- list(
  mtry = c(2, 50),
  max_depth = c(5, 30),
  number_trees = c(100, 1000)
)



# define the behavioural groupings to use
behaviour_columns <- c("Activity", "GeneralisedActivity")

feature_data <- fread(file.path(base_path, "Data", "FeatureOtherData_Clusters.csv"))
feature_data <- feature_data %>% as.data.table()

#for (behaviours in behaviour_columns){
  
  behaviours <- "GeneralisedActivity"
  print(behaviours)
  
  # multiclass_data <- feature_data %>%
  #   select(-(setdiff(behaviour_columns, behaviours))) %>%
  #   rename("Activity" = !!sym(behaviours)) %>%
  #   filter(!Activity == "")
  
  multiclass_data <- feature_data
  
  # Run the Bayesian Optimization
  results <- BayesianOptimization(
    FUN = function(number_trees, mtry, max_depth) {
      RFModelOptimisation(
        feature_data = multiclass_data,
        number_trees = number_trees,
        mtry = mtry,
        max_depth = max_depth
      )
    },
    bounds = bounds,
    init_points = 5,
    n_iter = 10,
    acq = "ucb",
    kappa = 2.576 
  )
#}
