# Master script for building the models for any given species etc ---------


p_load(rBayesianOptimization, 
       ranger)

species <- "Vehkaoja_Dog"

source(file = file.path(base_path, "Scripts", "ModelBuilding", "HPOFunctions.R"))
source(file = file.path(base_path, "Scripts", "ModelBuilding", "TestFunctions.R"))


# Split out test data -----------------------------------------------------
data <- fread(file.path(base_path, "Data", species, "Feature_data.csv"))

test_IDs <- sample(unique(data$ID), 0.2*length(unique(data$ID)))

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
  group_by(ID, Activity)

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
  n_iter = 3,
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
  select(c(!!!syms(clean_cols), "Activity", "ID")) %>% 
  select(-c(Time, ID)) %>%
  na.omit() %>%
  mutate(Activity = as.factor(Activity))
    
RF_model <- ranger(
  dependent.variable.name = "Activity",
  data = training_data,
  num.trees = best_number_trees,
  mtry = best_mtry,
  max.depth = best_max_depth,
  classification = TRUE,
  importance = "impurity"
)

# save this model
saveRDS(RF_model, file.path(base_path, "Data", species, "Activity_model.rds"))

# Make predictions --------------------------------------------------------
test_feature_data <- as.data.table(test_data)
numeric_testing_data <- test_feature_data %>%
  select(c(!!!syms(clean_cols), "Activity", "ID", "Time")) %>% 
  na.omit() %>%
  select(clean_cols) %>%
  select(-Time) %>%
  as.matrix()
testing_metadata <- test_feature_data %>%
  select(c(!!!syms(clean_cols), "Activity", "ID", "Time")) %>% 
  na.omit() %>%
  select("Activity", "ID", "Time")
ground_truth_labels <- factor(testing_metadata$Activity)

if (anyNA(numeric_testing_data)) message("Validation data contains missing values!")

# Make predictions
predictions <- predict(RF_model, data = numeric_testing_data)
predicted_classes <- factor(predictions$predictions, levels = levels(ground_truth_labels))

metrics <- compute_metrics(predicted_classes, ground_truth_labels)
predictions <- cbind(true_classes = ground_truth_labels, predicted_classes = predicted_classes)


# Write to CSV
write.csv(metrics$metrics, file = file.path(base_path, "Data", species, paste0("Original_performance_metrics.csv")), row.names = FALSE)
write.csv(predictions, file = file.path(base_path, "Data", species, paste0("Original_predictions.csv")), row.names = FALSE)
