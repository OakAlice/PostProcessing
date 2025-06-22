# LSTM Smoothing ----------------------------------------------------------
# the most powerful of my methods
# begin by hyperparameter tuning and then later retrain the final version
# code is currently very slow and needs to be vectorised / refactorised

# Functions ---------------------------------------------------------------
# Convert to the right structure
make_lstm_input <- function(data, window_size, class_levels) {
  n_classes <- length(class_levels)
  
  if (nrow(data) <= window_size) {
    warning(sprintf("Not enough observations (%d) for window size (%d)", 
                    nrow(data), window_size))
    return(NULL)
  }
  
  # have to do -1 so that it is indexed from 0 (necessary for package)
  encoded <- as.integer(factor(data$predicted_class, levels = class_levels)) - 1
  y_pred <- diag(n_classes)[encoded + 1, ] # +1 again so its back where it should be
  
  n_obs <- nrow(y_pred)
  X_array <- array(NA, dim = c(n_obs - window_size, window_size, n_classes))
  y_target <- as.integer(factor(data$true_class[(window_size + 1):n_obs], 
                                levels = class_levels))
  
  for (i in 1:(n_obs - window_size)) {
    X_array[i, , ] <- y_pred[i:(i + window_size - 1), ]
  }
  
  list(
    X = torch_tensor(X_array, dtype = torch_float()),
    y = torch_tensor(y_target, dtype = torch_long())
  )
}

# Train the model
train_lstm <- function(train_data, class_levels, epochs, window_size, hidden_size){
  
  n_classes <- length(class_levels)
  
  # format them
  train_input <- make_lstm_input(train_data, window_size, class_levels)
  
  model <- nn_module(
    "LSTMSmoother",
    initialize = function(input_size, hidden_size, output_size) {
      self$lstm <- nn_lstm(input_size = input_size, hidden_size = hidden_size, batch_first = TRUE)
      self$output <- nn_linear(hidden_size, output_size)
    },
    forward = function(x) {
      out <- self$lstm(x)[[1]]
      last_step <- out[ , dim(out)[2], ]
      self$output(last_step)
    }
  )
  
  net <- model(input_size = n_classes, hidden_size = hidden_size, output_size = n_classes)
  optimizer <- optim_adam(net$parameters, lr = 0.001)
  loss_fn <- nn_cross_entropy_loss()
  
  net$train()
  n_epochs <- epochs
  batch_size <- 128
  X <- train_input$X
  y <- train_input$y
  
  for (epoch in 1:n_epochs) {
    total_loss <- 0
    for (i in seq(1, X$size(1), by = batch_size)) {
      idx <- i:min(i + batch_size - 1, X$size(1))
      x_batch <- X[idx, , ]
      y_batch <- y[idx]
      
      optimizer$zero_grad()
      output <- net(x_batch)
      loss <- loss_fn(output, y_batch)
      loss$backward()
      optimizer$step()
      
      total_loss <- total_loss + loss$item()
    }
    cat(sprintf("Epoch %d: Loss %.4f\n", epoch, total_loss))
  }
  
  return(net)
}

# Apply the model
apply_lstm <- function(val_data, net, window_size, class_levels){
  
  val_input <- make_lstm_input(val_data, window_size, class_levels)
  # calculate
  X_test <- val_input$X
  net$eval()
  with_no_grad({
    preds <- net(X_test)
    smoothed_idx <- preds$argmax(dim = 2)$to(dtype = torch_int())
  })
  
  # Add smoothed predictions to test data
  val_data$smoothed_class <- NA_character_ 
  midpoints <- floor(window_size / 2):(floor(window_size / 2) + length(smoothed_idx) - 1)
  val_data$smoothed_class[midpoints] <- class_levels[as.numeric(smoothed_idx)] #+ 1]
  
  return(val_data)
}

# Code --------------------------------------------------------------------
## Split data into training and val ---------------------------------------
other_data <- fread(file.path(base_path, "Data", "StandardisedPredictions", paste0(species, "_train_data.csv"))) %>%
  na.omit() %>%
  group_by(ID, true_class) %>%
  arrange(Time) %>%
  mutate(row = row_number()) %>%
  mutate(split = ifelse(row > 0.8 * max(row), "val", "train"))

train_data <- other_data %>% filter(split == "train")
val_data <- other_data %>% filter(split == "val")

## Hyperparameter tuning ---------------------------------------------------
results <- list()
smoothed_predictions <- list()

parameters <- expand.grid(window_size = c(3, 5),
                   hidden_size = c(64, 128),
                   epochs = c(10, 20))

for (i in 1:nrow(parameters)){
  row <- parameters[i, ]
  
  class_levels <- levels(factor(train_data$predicted_class))
  net <- train_lstm(train_data, 
                       class_levels, 
                       epochs = row$epochs,
                       window_size = row$window_size, 
                       hidden_size = row$hidden_size)
  
  smoothed_data <- apply_lstm(val_data, 
                              net, 
                              window_size = row$window_size, 
                              class_levels)
  
  # Recalculate performance and save
  performance <- compute_metrics(smoothed_data$smoothed_class, smoothed_data$true_class)
    
  F1 <- performance$metrics$F1[metrics$Activity == "Macro-Average"]
  result <- cbind(row, F1)
  results[[i]] <- result
  
  preds <- smoothed_data %>% dplyr::select(Time, ID, true_class, predicted_class, smoothed_class)
    
  smoothed_predictions[[i]] <- preds
}

## Find the best parameters -----------------------------------------------
results <- bind_rows(results)
best_index <- which.max(results$F1)
best_parameters <- results[best_index, ]

## The final build --------------------------------------------------------
train_data <- fread(file.path(base_path, "Data", "StandardisedPredictions", paste0(species, "_train_data.csv"))) %>%
  na.omit() %>%
  arrange(ID, Time)
test_data <- fread(file.path(base_path, "Data", "StandardisedPredictions", paste0(species, "_test_data.csv"))) %>%
  na.omit() %>%
  arrange(ID, Time)

net <- train_lstm(train_data, 
                  class_levels, 
                  epochs = best_parameters$epochs,
                  window_size = best_parameters$window_size, 
                  hidden_size = best_parameters$hidden_size)

smoothed_data <- apply_lstm(test_data, 
                            net, 
                            window_size = best_parameters$window_size, 
                            class_levels)

## Recalculate performance and save ---------------------------------------
performance <- compute_metrics(smoothed_data$smoothed_class, smoothed_data$true_class)
metrics <- performance$metrics

fwrite(metrics, file.path(base_path, "Output", species, "LSTMSmoothing_performance.csv"))
generate_confusion_plot(performance$conf_matrix_padded,
                        save_path = file.path(base_path, "Output", species, "LSTMSmoothing_performance.pdf"))

# Calculate ecological results --------------------------------------------
ecological_data <- fread(file.path(base_path, "Data", "UnlabelledData", paste0(species, "_unlabelled_predicted.csv")))

smoothed_ecological_data <- apply_lstm(ecological_data, 
                            net, 
                            window_size = best_parameters$window_size, 
                            class_levels)

# calculate what this means
eco <- ecological_analyses(smoothing_type = "LSTM", 
                           eco_data = smoothed_ecological_data, 
                           target_activity = target_activity)
question1 <- eco$sequence_summary
question2 <- eco$hour_proportions

# write these to files
fwrite(question1, file.path(base_path, "Output", species, "LSTMSmoothing_eco1.csv"))
fwrite(question2, file.path(base_path, "Output", species, "LSTMSmoothing_eco2.csv"))


# Notes -------------------------------------------------------------------
# alternative emthod would be to use the much more popular keras
# but I could not get this to work for the life of me
# couldnt get a stable activation even when following instructions ->
# https://tensorflow.rstudio.com/install/
# should have been soemthing like:
  # install.packages("remotes")
  # remotes::install_github("rstudio/tensorflow") # do this once
  # tensorflow::install_tensorflow(envname = "r-tensorflow")
  # library(tensorflow)
# but then I would either need to constantly re-install or remove
  
