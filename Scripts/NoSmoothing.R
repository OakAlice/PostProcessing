# Testing performance of base predictions ---------------------------------

# loading in the standardised formats
data <- fread(file.path(base_path, "Data", "StandardisedFormat", paste0(species, "_test_data.csv")))

# no smoothing is performed, therefore just duplicate and rename the column without doing anything
data <- data %>% mutate(smoothed_class = predicted_class)

# now run it through the standardised performance testing mechanism
# for now this is very simple, but I will add to it as I go

# performance metrics
performance <- compute_metrics(data$smoothed_class, data$true_class)
metrics <- performance$metrics

# save these
fwrite(metrics, file.path(base_path, "Output", species, "NoSmoothing_performance.csv"))
generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, "NoSmoothing_performance.pdf"))


