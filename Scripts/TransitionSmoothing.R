# Transition Matrix Smoothing ---------------------------------------------
# similar to the confusion method but based on transition probabilities.

data <- fread(file.path(base_path, "Data", "StandardisedFormat", paste0(species, "_raw_standardised.csv")))

# Assessing Continuousness ------------------------------------------------
# before we use this method, we need to establish how "realistic" our data is
# as in, has it been collected in natural sequence from which we can derive natural sequence probabilities?
# to do this, look at how much of the data is continuous per individual

# difference between times +/- 10%
time_diff <- continuousness[1, "Time"] - continuousness[2, "Time"]
time_max <- time_diff * 2
time_min <- 0.5*time_diff

continuousness <- data %>%
  group_by(ID) %>%
  arrange(Time) %>%
  mutate(
    diff_time = shift(Time, type = "lag") - Time)

continuousness$break_point <- if(diff_time > time_max & diff_time < time_min){
        0 
      } else {
        1
      }
continuousness <- continuousness %>% 
  group_by(ID) %>%
  arrange(Time) %>%
  mutate(break_point = replace_na(break_point, 0),
         sequence = cumsum(break_point))




# Find all the break points -----------------------------------------------
# mark whenever there is a change in behaviour
data <- data %>%
  arrange(ID, Time) %>%
  group_by(ID) %>%
  mutate(
    change_point = ifelse(shift(predicted_class, type = "lag") == predicted_class, 0, 1),
    change_point = replace_na(change_point, 0)
  ) %>%
  ungroup()

# Assess the validity of those changes ------------------------------------
# for every change, assess transition probability
data$smoothed_class <- NA
for (i in 1:length(data$change_point)){
  data$smoothed_class[i] <- data$predicted_class[i] # default set it to be itself
  
  change <- data$change_point[i]
  if (change == 1){
    
    #add code here later
  }
}

# Recalculate performance and save ----------------------------------------
performance <- compute_metrics(data$smoothed_class, data$true_class)
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, "ConfusionSmoothing_performance.csv"))
generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, "ConfusionSmoothing_performance.pdf"))


