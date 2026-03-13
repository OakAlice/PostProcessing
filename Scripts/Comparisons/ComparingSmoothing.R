# Compiling the resulsts for a single dataset

metrics_list <- list.files(
  file.path(base_path, "Output", species),
  pattern = "_performance_.*\\.csv$",
  full.names = TRUE
)

metrics <- lapply(metrics_list, function(file) {
  fread(file) %>%
    mutate(smoothing_type = basename(file),
           rep_id = str_split(tools::file_path_sans_ext(basename(file)), "_")[[1]][3]) %>%
    rename(Activity = 1) # rename to Activity in all cases
})

# remove Class: from the Activity and .csv from the smoothing_type
metrics <- rbindlist(metrics) %>%
  mutate(
    Activity = gsub("Class: ", "", Activity), ## also change this between activity and behaviour
    smoothing_type = gsub("_performance_.*\\.csv$", "", smoothing_type)
  ) %>%
  select(!Prevelance) %>%
  na.omit()

metrics <- metrics %>% 
  mutate(smoothing_type = gsub("Smoothing", "", smoothing_type))

# add levels so its easier to plot later
metrics$smoothing_type <- factor(metrics$smoothing_type, levels = c("No", "Mode", "Duration", "Transition", "HMM", "Bayesian"))

metrics_long <- metrics %>%
  pivot_longer(cols = c(Precision, Recall, F1, Accuracy),
               names_to = "Metric",
               values_to = "Score")

fwrite(metrics_long, file.path(base_path, "Output", species, "all_smoothed_metrics.csv"))