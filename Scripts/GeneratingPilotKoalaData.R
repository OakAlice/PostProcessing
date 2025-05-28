# Generating the koala data -----------------------------------------------

library(ranger)

# just really quickly apply the model to the data and extract the predictions and ground-truths
data <- fread(file.path(base_path, "Data", "TestPredictions", "Sparkes_Koala", "FeatureTestData.csv"))
model <- readRDS(file.path(base_path, "Data", "TestPredictions", "Sparkes_Koala", "Activity_model.rds"))

# extract the features and the metadata from the data
selected_features <- model[["forest"]][["independent.variable.names"]]

clean_data <- na.omit(data[, c(selected_features, "Time", "ID", "Activity", "GeneralisedActivity"), with = FALSE])
numeric_data <- clean_data %>% select(c(selected_features)) %>% as.matrix()
metadata <- clean_data[, .(Time, ID, Activity, GeneralisedActivity)]

predictions <- predict(model, data = numeric_data)$predictions
predictions_df <- cbind(predicted_classes = factor(predictions), metadata)

# rename the columns
predictions_df <- predictions_df %>% rename(
  Time = Time,
  ID = ID,
  true_class = Activity,
  generalised_class = GeneralisedActivity,
  predicted_class = predicted_classes
)

# save this as the koala data for me to run the pilot experiment on
fwrite(predictions_df, file.path(base_path, "Data", "StandardisedFormat", "Sparkes_Koala_raw_standardised.csv"))
