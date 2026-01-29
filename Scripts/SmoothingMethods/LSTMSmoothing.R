# LSTM Smoothing ----------------------------------------------------------
# the most powerful of my methods
# begin by hyperparameter tuning and then later retrain the final version
# code is currently very slow and needs to be vectorised / refactorised

# Functions ---------------------------------------------------------------
# Convert to the right structure
make_lstm_input <- function(data, window_size, class_levels) {
  n_classes <- length(class_levels)
  
  if (nrow(data) <= window_size) {
    warning(sprintf(
      "Not enough observations (%d) for window size (%d)",
      nrow(data), window_size
    ))
    return(NULL)
  }
  
  # Encode predicted classes (0-based)
  encoded_pred <- as.integer(
    factor(data$predicted_class, levels = class_levels)
  ) - 1L
  
  if (anyNA(encoded_pred)) {
    stop("NA in encoded predicted_class: class not in class_levels")
  }
  
  y_pred <- diag(n_classes)[encoded_pred + 1L, ]
  
  n_obs <- nrow(y_pred)
  
  X_array <- array(
    NA_real_,
    dim = c(n_obs - window_size, window_size, n_classes)
  )
  
  # Encode true classes (0-based)
  y_target <- as.integer(
    factor(
      data$true_class[(window_size + 1):n_obs],
      levels = class_levels
    )
  ) - 1L
  
  if (anyNA(y_target)) {
    stop("NA in encoded true_class: class not in class_levels")
  }
  
  for (i in seq_len(n_obs - window_size)) {
    X_array[i, , ] <- y_pred[i:(i + window_size - 1L), ]
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
      last_step <- out[, out$size()[2], ]
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
    n <- X$size()[1]
    for (i in seq(1, n, by = batch_size)) {
      idx <- i:min(i + batch_size - 1, n)
      x_batch <- X[idx, , ]
      y_batch <- y[idx]
      
      optimizer$zero_grad()
      output <- net(x_batch)
      
      loss <- tryCatch(
        {
          l <- loss_fn(output, y_batch)
          
          if (!is.finite(l$item())) {
            stop("Invalid loss")
          }
          
          l
        },
        error = function(e) NULL
      )
      
      
      if (is.null(loss)) {
        next  # skip this batch
      }
      
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
# in this case we are going to learn from the training data... 
# to do this, we have to predict the model back onto the training data.

if (
  !file.exists(file.path(base_path, "Output", species, paste0("LSTMSmoothing_performance_", i, ".csv"))) ||
  difftime(Sys.time(), file.info(file.path(base_path, "Output", species, paste0("LSTMSmoothing_performance_", i, ".csv")))$mtime, units = "hours") > hours_since_creation
) {
  
other_data <- fread(file = file.path(base_path, "Data", species, paste0("Training_predictions_", i, ".csv"))) %>%
  mutate(split = ifelse(ID %in% sample(unique(other_data$ID), 0.8*length(unique(other_data$ID))), "train", "val"))

train_data <- other_data %>% dplyr::filter(split == "train") %>% select(!split)
val_data <- other_data %>% dplyr::filter(split == "val") %>% select(!split)

## Hyperparameter tuning ---------------------------------------------------
results <- list()
smoothed_predictions <- list()

parameters <- expand.grid(window_size = c(3, 5),
                   hidden_size = c(64, 128),
                   epochs = c(10, 20))

for (j in 1:nrow(parameters)){
  row <- parameters[j, ]
  
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
  performance <- compute_metrics(as.factor(smoothed_data$smoothed_class), as.factor(smoothed_data$true_class))
    
  colnames(performance$metrics) <- c("Activity", "Precision", "Recall", "F1", "Accuracy", "Prevelance") # hardcoding this because I was getting issues with column names 
  
  F1 <- performance$metrics$F1[performance$metrics$Activity == "Macro-Average"] ## changing this between behaviour and activity
  
  # if this line errors its probably because the activity column has been set to Behaviour somehow... 
  result <- cbind(row, F1)
  results[[j]] <- result
  
  preds <- smoothed_data %>% dplyr::select(Time, ID, true_class, predicted_class, smoothed_class)
    
  smoothed_predictions[[j]] <- preds
}

## Find the best parameters -----------------------------------------------
results <- bind_rows(results)
best_index <- which.max(results$F1)
best_parameters <- results[best_index, ]

## The final build --------------------------------------------------------
train_data <- fread(file.path(base_path, "Data", species, paste0("Training_predictions_", i, ".csv"))) %>%
  na.omit() %>%
  arrange(ID, Time)

net <- train_lstm(train_data, 
                  class_levels, 
                  epochs = best_parameters$epochs,
                  window_size = best_parameters$window_size, 
                  hidden_size = best_parameters$hidden_size)


# Apply to the test data --------------------------------------------------
test_data <- fread(file.path(base_path, "Data", species, paste0("Original_predictions_", i, ".csv"))) %>%
  as.data.frame() %>%
  arrange(ID, Time) 

# again, split into sequences and run across each of the sequences
test_data <- identify_sequences(test_data, max_break = ifelse(sample_rates[[species]] > 1, 3, 6)) # based on window duration and buffer
test_data$set <- paste(test_data$ID, test_data$sequence, sep = "_")

# run the hmm over each of the sequences and save the smoothed class
test_data <- lapply(unique(test_data$set), function(x){
  dat <- test_data %>% dplyr::filter(set == x)
  if (nrow(dat) < 2) {
    dat$smoothed_class <- dat$predicted_class
    return(dat)
  }
  dat <- apply_lstm(test_data,
                    net,
                    window_size = best_parameters$window_size,
                    class_levels)
  
  dat
})


## Recalculate performance and save ---------------------------------------
performance <- compute_metrics(as.factor(smoothed_data$smoothed_class), as.factor(smoothed_data$true_class))
metrics <- performance$metrics

fwrite(metrics, file.path(base_path, "Output", species, paste0("LSTMSmoothing_performance_", i, ".csv")))
#generate_confusion_plot(performance$conf_matrix_padded,
#                        save_path = file.path(base_path, "Output", species, paste0("LSTMSmoothing_performance_", i, ".pdf")))

} else {
  print("already did this one recently")
}

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
  
