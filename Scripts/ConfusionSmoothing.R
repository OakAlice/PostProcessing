# Confusion Smoothing -----------------------------------------------------
# not all predictions are created equal
# the confusion matrix from the model creation step tells us information about which predictions are better than others
# using this information we will improve on duration based smoothing

# Understand the Confusion Matrix -----------------------------------------
# generate the confusion matric
data <- fread(file.path(base_path, "Data", "StandardisedFormat", paste0(species, "_raw_standardised.csv")))
performance <- compute_metrics(data$predicted_class, data$true_class)
confusion <- as.matrix(performance$conf_matrix_padded)

# generate a miscalssification likelihood table
# interpretation: given the pred_class, there is a % likelihood that its actually the true_class
# when pred = true, hopefully a high % but also provides misclassification rates
confusion_likelihood <- as.data.frame(as.table(confusion)) %>%
  rename(true_class = 1, predicted_class = 2, n = Freq) %>% # 1 and 2 are the dimnames
  group_by(true_class) %>%
  mutate(
    total = sum(n),
    likelihood_classification = round(n / total, 2)
  ) %>%
  ungroup() %>%
  arrange(true_class, desc(likelihood_classification))

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
# for every change, assess probability that it could be the class that preceded or followed it
data$smoothed_class <- NA
for (i in 1:length(data$change_point)){
  data$smoothed_class[i] <- data$predicted_class[i] # default set it to be itself
  
  change <- data$change_point[i]
  if (change == 1){
    
    # find the label before and after
    before <- data$predicted_class[i - 1]
    after <- data$predicted_class[i + 1]
    
    # check that its not already in a sequence
    if (data$predicted_class[i] == before | data$predicted_class[i] == after){
      next
    }
    
    # whats the probability that my event is a misclassification of either of the others?
    probability_before <- confusion_likelihood$likelihood_classification[confusion_likelihood$true_class == before & confusion_likelihood$predicted_class == event]
    probability_after <- confusion_likelihood$likelihood_classification[confusion_likelihood$true_class == after & confusion_likelihood$predicted_class == event]
    
    probs <- data.table(c("before", "after"), c(before, after), c(probability_before, probability_after))
    colnames(probs) <- c("sequence", "label", "probability")
    
    highest_prob <- probs %>% arrange(desc(probability)) %>% head(1)
    
    # is this above threshold?
    #### TODO: User defined?
    threshold <- 0.3
    if (highest_prob$probability > threshold){
      data$smoothed_class[i] <- highest_prob$label
    }
  }
}

# Recalculate performance and save ----------------------------------------
performance <- compute_metrics(data$smoothed_class, data$true_class)
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, "ConfusionSmoothing_performance.csv"))
generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, "ConfusionSmoothing_performance.pdf"))


