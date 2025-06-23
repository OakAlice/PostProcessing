# Testing optimal models --------------------------------------------------
# Function to apply column selection changes to both training and testing data
update_feature_data <- function(data, multi) {
  
  cols_to_remove <- c("Activity", "GeneralisedActivity")
  # classes to remove logic
 if (multi == "GeneralisedActivity") {
    col_to_rename <- "GeneralisedActivity"
  } else if (multi == "Activity") {
    col_to_rename <- "Activity"
  }
  
  data <- data %>% select(-(setdiff(cols_to_remove, col_to_rename))) %>%
    rename(Activity = col_to_rename)
  
  return(data)
}

# because I'm lazy and sometimes just run this script independently
library(ggplot2)
library(caret)
library(data.table)
library(tidyverse)


# Function to generate and save a confusion matrix plot
generate_confusion_plot <- function(conf_matrix_padded, base_path, save_path) {
  
  # Extracting confusion matrix data and reshaping it
  conf_matrix_df <- as.data.frame(as.table(conf_matrix_padded))
  colnames(conf_matrix_df) <- c("Predicted", "Actual", "Count")
  
  # Repeat rows based on the Count column (i.e., add multiple rows for each count)
  conf_matrix_df_repeated <- conf_matrix_df[rep(1:nrow(conf_matrix_df), conf_matrix_df$Count), ]
  
  # Create a new column to classify the points as True Positive, False Positive, etc.
  conf_matrix_df_repeated$Type <- "Other"
  conf_matrix_df_repeated$Type[conf_matrix_df_repeated$Predicted == conf_matrix_df_repeated$Actual] <- "True Positive"
  conf_matrix_df_repeated$Type[conf_matrix_df_repeated$Predicted != conf_matrix_df_repeated$Actual] <- "False Positive"
  
  # Assign colors based on classification type
  conf_matrix_df_repeated$Color <- ifelse(conf_matrix_df_repeated$Type == "True Positive", "blue", "red")
  
  # Plotting with jitter
  confusion_plot <- ggplot(conf_matrix_df_repeated, aes(x = Predicted, y = Actual, color = Color)) +
    geom_jitter(width = 0.1, height = 0.1, alpha = 0.3, size = 2) +  # Add jitter with fixed point size
    scale_color_manual(values = c("blue", "red")) +
    labs(x = "Predicted Class", 
         y = "Actual Class") +
    theme_minimal() +
    theme(legend.position = "bottom")
  
  # Save the plot to a PDF
  ggsave(save_path,
         plot = confusion_plot, width = 16, height = 8)
}

# Function to compute confusion matrix metrics
compute_metrics <- function(predicted_classes, ground_truth_labels) {
  # Compute confusion matrix
  confusion_matrix <- table(predicted_classes, ground_truth_labels)
  all_classes <- union(levels(predicted_classes), levels(ground_truth_labels))
  
  # Create a padded confusion matrix
  conf_matrix_padded <- matrix(0, nrow = length(all_classes), ncol = length(all_classes),
                               dimnames = list(all_classes, all_classes))
  conf_matrix_padded[rownames(confusion_matrix), colnames(confusion_matrix)] <- confusion_matrix
  
  # Calculate F1 score and other metrics using confusionMatrix from caret
  confusion_mtx <- confusionMatrix(conf_matrix_padded)
  
  # Extract precision, recall, F1-score, accuracy, and prevalence
  metrics <- data.frame(
    Behaviour = rownames(confusion_mtx$byClass),  # Behaviour names (classes)
    Precision = confusion_mtx$byClass[, "Precision"],
    Recall = confusion_mtx$byClass[, "Recall"],
    F1 = confusion_mtx$byClass[, "F1"],
    Accuracy = confusion_mtx$byClass[, "Balanced Accuracy"],
    Prevelance = confusion_mtx$byClass[, "Prevalence"] * length(predicted_classes)
  )
  
  # Add macro-averaged metrics as the last row
  metrics <- rbind(
    metrics,
    data.frame(
      Behaviour = "Macro-Average",
      Precision = mean(metrics$Precision, na.rm = TRUE),
      Recall = mean(metrics$Recall, na.rm = TRUE),
      F1 = mean(metrics$F1, na.rm = TRUE),
      Accuracy = mean(metrics$Accuracy, na.rm = TRUE),
      Prevelance = NA
    )
  )
  
  return(list(metrics = metrics,
           conf_matrix_padded = conf_matrix_padded))
}