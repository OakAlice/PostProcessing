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

# pausing here to figure out how I should do this... mode based or break-point based?
# notes in obsidian
# I should also probably go to bed.. its getting late and I have to start fieldwork at 4 am

