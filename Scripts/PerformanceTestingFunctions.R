# Function for testing performance ----------------------------------------

# Plot of confusion matric ------------------------------------------------
generate_confusion_plot <- function(conf_matrix_padded, save_path) {
  
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
  
  # Create a padded confusion matrix (in case there are missing classes)
  conf_matrix_padded <- matrix(0, nrow = length(all_classes), ncol = length(all_classes),
                               dimnames = list(all_classes, all_classes))
  conf_matrix_padded[rownames(confusion_matrix), colnames(confusion_matrix)] <- confusion_matrix
  
  # Calculate F1 score and other metrics using confusionMatrix from caret
  confusion_mtx <- caret::confusionMatrix(conf_matrix_padded)
  
  byClass <- confusion_mtx$byClass
  
  # If binary, convert named vector to 1-row matrix first
  # fails in the desantis_rattlesnake condition if I dont do this
  if (is.null(dim(byClass))) {
    byClass <- t(as.matrix(byClass))
    rownames(byClass) <- colnames(conf_matrix_padded)[2]  # positive class
  }
  
  metrics <- data.frame(
    Behaviour  = rownames(byClass),
    Precision  = byClass[, "Precision"],
    Recall     = byClass[, "Recall"],
    F1         = byClass[, "F1"],
    Accuracy   = byClass[, "Balanced Accuracy"],
    Prevelance = byClass[, "Prevalence"] * length(predicted_classes),
    row.names  = NULL
  )
  
  # Add macro-averaged metrics as the last row
  # do not na.rm = TRUE otherwise the model can cheat and move towards not predicting classes at all
  metrics[is.na(metrics)] <- 0
  metrics <- rbind(
    metrics,
    data.frame(
      Behaviour = "Macro-Average",
      Precision = mean(metrics$Precision),
      Recall = mean(metrics$Recall),
      F1 = mean(metrics$F1),
      Accuracy = mean(metrics$Accuracy),
      Prevelance = NA
    )
  )
  
  return(list(metrics = metrics,
              conf_matrix_padded = conf_matrix_padded))
}
