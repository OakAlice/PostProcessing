# Master script for building the models for any given species etc ---------

p_load(rBayesianOptimization, 
       ranger)

source(file = file.path(base_path, "Scripts", "ModelBuilding", "HPOFunctions.R"))
source(file = file.path(base_path, "Scripts", "ModelBuilding", "TestFunctions.R"))

# Split out test data -----------------------------------------------------
data <- fread(file.path(base_path, "Data", species, "Feature_data.csv"))

test_IDs <- sample(unique(data$ID), 0.4*length(unique(data$ID)))
print(paste0("number of individuals in the test set: ", length(test_IDs)))

test_data <- data %>% filter(ID %in% test_IDs)
other_data <- data %>% filter(!ID %in% test_IDs)                      

# Model design: hyperparameter tuning -------------------------------------
# Based on a random forest, what hyperparamaters are best?
  bounds <- list(
    mtry = c(2, 50),
    max_depth = c(5, 30),
    number_trees = c(100, 1000)
  )
  
  other_data <- other_data %>% as.data.table() %>%
    group_by(ID, Activity) #%>%
    #slice(1:100) ## REMOVE THIS WHEN YOU're SERIOUES
  
  # this is optimised for weighted F1 score
  results <- BayesianOptimization(
    FUN = function(number_trees, mtry, max_depth) {
      RFModelOptimisation(
        feature_data = other_data,
        data_split = "individual",
        number_trees = number_trees,
        mtry = mtry,
        max_depth = max_depth
      )
    },
    bounds = bounds,
    init_points = 2,
    n_iter = 5,
    acq = "ucb",
    kappa = 2.576 
  )
  
  # extract the best ones
  best_mtry <- round(results$Best_Par[["mtry"]],0)
  best_number_trees <- round(results$Best_Par[["number_trees"]],0)
  best_max_depth <- round(results$Best_Par[["max_depth"]],0)
  best_performance <- results$Best_Value # just for interest
  
# Train an optimal model --------------------------------------------------
  other_feature_data <- as.data.table(other_data)
  clean_cols <- removeBadFeatures(other_feature_data, var_threshold = 0.5, corr_threshold = 0.9)
  training_data <- other_feature_data %>%
    select(c(!!!syms(clean_cols), "Activity")) %>%
    na.omit() %>%
    mutate(Activity = as.factor(Activity))
      
  # weight by class frequency
  class_freq <- table(training_data$Activity)
  class_weights <- 1 / class_freq
  class_weights <- class_weights / sum(class_weights)
  weight <- class_weights[training_data$Activity]
  
  RF_model <- ranger(
    dependent.variable.name = "Activity",
    data = training_data,
    num.trees = best_number_trees,
    mtry = best_mtry,
    max.depth = best_max_depth,
    classification = TRUE,
    probability = TRUE,
    importance = "impurity",
    case.weights = weight
  )
  
  # save this model
  saveRDS(RF_model, file.path(base_path, "Data", species, "Activity_model.rds"))

# Make predictions --------------------------------------------------------
test_feature_data <- as.data.table(test_data)
complete_cases <- test_feature_data %>%
  select(all_of(c(clean_cols, "Activity", "ID", "Time"))) %>%
  na.omit()

numeric_testing_data <- complete_cases %>%
  select(all_of(clean_cols)) %>%
  as.matrix()
if (anyNA(numeric_testing_data)) message("Validation data contains missing values!")

testing_metadata <- complete_cases %>%
  select(Activity, ID, Time)
ground_truth_labels <- factor(testing_metadata$Activity)

# Make predictions
output <- predict(RF_model, data = numeric_testing_data, probability = TRUE)
predictions <- output$predictions
predicted_class <- colnames(predictions)[max.col(predictions, ties.method = "first")]
predictions_df <- cbind(testing_metadata, predictions, predicted_class)
predictions_df <- predictions_df %>% rename(true_class = Activity)

metrics <- compute_metrics(predicted_classes = as.factor(predictions_df$predicted_class), 
                           ground_truth_labels = as.factor(predictions_df$true_class))

# Write to CSV
write.csv(metrics$metrics, file = file.path(base_path, "Data", species, paste0("Original_performance_metrics.csv")), row.names = FALSE)
write.csv(predictions_df, file = file.path(base_path, "Data", species, paste0("Original_predictions.csv")), row.names = FALSE)

# Make predictions back on the training data ------------------------------
# due to limitations of data availability for most of the datasets
# to get more model trainign data, I have to predict back onto the training data
# maybe change this later?
training_feature_data <- as.data.table(other_feature_data)
complete_cases <- training_feature_data %>%
  select(all_of(c(clean_cols, "Activity", "ID", "Time"))) %>%
  na.omit()
numeric_training_data <- complete_cases %>%
  select(all_of(clean_cols)) %>%
  as.matrix()

training_metadata <- complete_cases %>%
  select(Activity, ID, Time)
ground_truth_labels <- factor(training_metadata$Activity)

# Make predictions
output <- predict(RF_model, data = numeric_training_data, probability = TRUE)
predictions <- output$predictions
predicted_class <- colnames(predictions)[max.col(predictions, ties.method = "first")]
predictions_df <- cbind(training_metadata, predictions, predicted_class)
predictions_df <- predictions_df %>% rename(true_class = Activity)

metrics <- compute_metrics(predicted_classes = as.factor(predictions_df$predicted_class), 
                           ground_truth_labels = as.factor(predictions_df$true_class))

# Write to CSV
write.csv(predictions_df, file = file.path(base_path, "Data", species, paste0("Training_predictions.csv")), row.names = FALSE)
