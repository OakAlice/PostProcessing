# Generating the koala data -----------------------------------------------

library(ranger)

# model I built earlier that wasn't probilitic
model <- readRDS(file.path(base_path, "Data", "TestPredictions", "Sparkes_Koala", "Activity_model.rds"))
selected_features <- model[["forest"]][["independent.variable.names"]]

# Train a model -----------------------------------------------------------
train_data <- fread(file.path(base_path, "Data", "TestPredictions", "Sparkes_Koala", "FeatureTrainingData.csv"))
train_data_clean <- na.omit(train_data[, c(selected_features, "Activity"), with = FALSE])
train_data_clean <- train_data_clean[!train_data_clean$Activity == "", ]
train_data_clean$Activity <- droplevels(as.factor(train_data_clean$Activity))

# define hyperparmaters - I know these from previous optimisation in KoalaAnalysis project
number_trees <- 169
mtry <- 9
max.depth <- 24

RF_model <- ranger(
  dependent.variable.name = "Activity",
  data = train_data_clean,
  num.trees = number_trees,
  mtry = mtry,
  max.depth = max.depth,
  classification = TRUE,
  probability = TRUE, 
  importance = "impurity"
)

# save this model
saveRDS(RF_model, file.path(base_path, "Data", "TestPredictions", "Sparkes_Koala", "Activity_model.rds"))

# Apply to the test data --------------------------------------------------
test_data <- fread(file.path(base_path, "Data", "TestPredictions", "Sparkes_Koala", "FeatureTestData.csv"))

# extract the features and the metadata from the data
selected_features <- RF_model[["forest"]][["independent.variable.names"]]

clean_data <- na.omit(test_data[, c(selected_features, "Time", "ID", "Activity", "GeneralisedActivity"), with = FALSE])
numeric_data <- clean_data %>% dplyr::select(c(selected_features)) %>% as.matrix()
metadata <- clean_data[, .(Time, ID, Activity, GeneralisedActivity)]

output <- predict(RF_model, data = numeric_data)
predictions <- output$predictions
predicted_class <- colnames(predictions)[max.col(predictions, ties.method = "first")]
predictions_df <- cbind(metadata, predictions, predicted_class)

# save this as the koala data for me to run the pilot experiment on
fwrite(predictions_df, file.path(base_path, "Data", "StandardisedFormat", "Sparkes_Koala_test_data.csv"))


# Apply to the training data as well --------------------------------------
# trying to see if this will help me do something elsewhere
train_data <- fread(file.path(base_path, "Data", "TestPredictions", "Sparkes_Koala", "FeatureTrainingData.csv"))
selected_features <- RF_model[["forest"]][["independent.variable.names"]]

clean_data <- na.omit(train_data[, c(selected_features, "Time", "ID", "Activity", "GeneralisedActivity"), with = FALSE])
numeric_data <- clean_data %>% dplyr::select(c(selected_features)) %>% as.matrix()
metadata <- clean_data[, .(Time, ID, Activity, GeneralisedActivity)]

output <- predict(RF_model, data = numeric_data)
predictions <- output$predictions
predicted_class <- colnames(predictions)[max.col(predictions, ties.method = "first")]
predictions_df <- cbind(metadata, predicted_class)
predictions_df <- predictions_df %>% rename(true_class = Activity)

# save this as the koala data for me to run the pilot experiment on
fwrite(predictions_df, file.path(base_path, "Data", "StandardisedFormat", "Sparkes_Koala_train_data.csv"))




# Predict onto the unlabelled data ----------------------------------------
RF_model <- readRDS(file.path(base_path, "Data", "TestPredictions", "Sparkes_Koala", "Activity_model.rds"))
selected_features <- RF_model[["forest"]][["independent.variable.names"]]

# Apply to the test data --------------------------------------------------
ec_dat_files <- list.files(file.path(base_path,"Data", "UnlabelledData", species, "Angelina"), recursive = TRUE, full.names = TRUE)

for (file in ec_dat_files){
  dat <- fread(file)
  name <- basename(file)
  clean_data <- na.omit(dat[, c(selected_features, "Time", "ID"), with = FALSE])
  numeric_data <- clean_data %>% dplyr::select(c(selected_features)) %>% as.matrix()
  metadata <- clean_data[, .(Time, ID)]
  
  output <- predict(RF_model, data = numeric_data)
  predictions <- output$predictions
  predicted_class <- colnames(predictions)[max.col(predictions, ties.method = "first")]
  predictions_df <- cbind(metadata, predictions, predicted_class)
  
  # save this as the predictions
  fwrite(predictions_df, file.path(base_path, "Data", "UnlabelledData", species, "PredictedData", name))
}


ec_pred_files <- list.files(file.path(base_path,"Data", "UnlabelledData", species, "PredictedData"), recursive = TRUE, full.names = TRUE)

ecological_data <- lapply(ec_pred_files, read.csv) %>% bind_rows()
# rename the columns to make them match
ecological_data <- ecological_data %>%
  rename("Bound/Half-Bound" = "Bound.Half.Bound",
         "Branch Walking" = "Branch.Walking",
         "Climbing Down" = "Climbing.Down",
         "Climbing Up" = "Climbing.Up",
         "Foraging/Eating" = "Foraging.Eating",
         "Rapid Climbing" = "Rapid.Climbing",
         "Sleeping/Resting" = "Sleeping.Resting",
         "Swinging/Hanging" = "Swinging.Hanging",
         "Tree Movement" = "Tree.Movement",
         "Tree Sitting" = "Tree.Sitting"
         )

# save this
fwrite(ecological_data, file.path(base_path, "Data", "UnlabelledData", paste0(species, "_unlabelled_predicted.csv")))
