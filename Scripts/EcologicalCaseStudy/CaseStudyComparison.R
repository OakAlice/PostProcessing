# Ecological Testing Functions --------------------------------------------
# the other way to test the performance of the model is to see how it answers an 
# ecological question of choice
# Here we are using the labelled and unlabelled data from the koala and comparing performance
# in the known and unknown scenarios

# Functions ---------------------------------------------------------------
# summarise the behaviours
summarise_behaviour_sequences <- function(unlabelled_files, target_activity) {
  
  dt <- lapply(unlabelled_files, function(x) {
    smoothing_type <- gsub(
      "Smoothing", "",
      stringr::str_split(basename(x), "_")[[1]][1]
    )
    dt <- fread(x) %>% 
      select(any_of(c("ID", "Time", "smoothed_class", "true_class")))
    dt$smoothing_type <- smoothing_type
    dt
  })
  dt <- rbindlist(dt)
  dt <- as.data.frame(dt)
  
  if ("true_class" %in% colnames(dt)){
    true_classes <- dt %>%
      dplyr::filter(smoothing_type == "No") %>% 
      dplyr::select(ID, Time, true_class) %>% 
      dplyr::mutate(
        smoothed_class = true_class,
        smoothing_type = "TrueClass"
      )
    dt <- dplyr::bind_rows(dt, true_classes)
  }
  
  # define the sequences
  dt <- identify_sequences(dt, max_break = ifelse(sample_rates[[species]] > 1, 3, 6)) # based on window duration and buffer
  dt <- dt %>%
    group_split(smoothing_type) %>%
    lapply(identify_events, class_col = "smoothed_class") %>%
    bind_rows()
  
  # Extract target behaviour sequences and find the means
  events <- dt %>%
    filter(smoothed_class == target_activity) %>%
    group_by(ID, smoothing_type, event) %>%
    summarise(
      Duration = n() * 2,
      .groups = "drop"
    )
  per_individual <- events %>%
    group_by(ID, smoothing_type) %>%
    summarise(
      freq = n(),
      mean_duration = mean(Duration),
      .groups = "drop"
    )
  summary_stats <- per_individual %>%
    group_by(smoothing_type) %>%
    summarise(
      mean_freq = mean(freq),
      sd_freq   = sd(freq),
      mean_duration = mean(mean_duration),
      sd_duration   = sd(mean_duration),
      .groups = "drop"
    )

  return(summary_stats)
}

# make the plot
make_smoothing_plot <- function(smoothed_files, output_name) {
  
  fill_colours = c(
    "coral", "khaki2", "aquamarine3", "powderblue", "orchid2" )
  
  # Load and combine smoothed predictions
  behavioural_plotdt <- lapply(smoothed_files, function(x) {
    smoothing_type <- gsub("Smoothing", "", stringr::str_split(basename(x), "_")[[1]][1])
    
    fread(x) %>%
      dplyr::select(any_of(c("ID", "Time", "smoothed_class", "true_class"))) %>%
      dplyr::mutate(smoothing = smoothing_type)
  })
  behavioural_plotdt <- data.table::rbindlist(behavioural_plotdt)
  
  behavioural_plotdt$smoothing <- factor(behavioural_plotdt$smoothing, 
                                         levels = c("No", "Mode", "Duration", "Transition", "HMM", "Bayesian"))
  
  # Add true labels as separate "smoothing" level
  if ("true_class" %in% colnames(behavioural_plotdt)){
    true_classes <- behavioural_plotdt %>%
      dplyr::filter(smoothing == "No") %>% 
      dplyr::select(ID, Time, true_class) %>% 
      dplyr::mutate(
        smoothed_class = true_class,
        smoothing = "TrueClass"
      )
    
    behavioural_plotdt <- rbind(behavioural_plotdt, true_classes, use.names = TRUE)
    
    behavioural_plotdt$smoothing <- factor(behavioural_plotdt$smoothing,
      levels = c("TrueClass", "No", "Mode", "Duration", "Transition", "HMM", "Bayesian")
    )
  }
  
  behavioural_plotdt <- behavioural_plotdt %>%
    arrange(ID, smoothing, Time) %>%
    group_by(ID, smoothing) %>%
    mutate(
      rel_time = row_number() * 2,
      rel_time_hr = rel_time / ifelse(output_name == "Unlabelled", 3600, 60)
    ) %>%
    ungroup()
  
  # plot it
  smoothing_plot <- ggplot(
    behavioural_plotdt,
    aes(x = rel_time_hr, y = as.factor(1), fill = as.factor(smoothed_class))
  ) +
    geom_tile() +
    labs(fill = "Activity", x = ifelse(output_name == "Unlabelled", "Time (hours)", "Time (minutes)")) +
    my_theme() +
    theme(
      strip.text = element_text(size = 14),
      axis.title.y  = element_blank(),
      axis.text.y   = element_blank(),
      axis.ticks.y  = element_blank(),
      legend.position = "bottom"
    ) +
    scale_x_continuous(breaks = seq(0, max(behavioural_plotdt$rel_time_hr), by = ifelse(output_name == "Unlabelled", 2, 5))) +
    scale_fill_manual(values = fill_colours) +
    facet_grid(
      rows = vars(smoothing),
      cols = vars(ID),
      scales = "free",
      drop = TRUE
    )
  
  # svae it
  out_path <- file.path(
    base_path, "CaseStudy", "Sparkes_Koala",
    paste0(output_name, "_smoothing_plot.png")
  )
  
  ggsave(
    filename = out_path,
    plot = smoothing_plot,
    width = 35,
    height = 20,
    units = "cm",
    dpi = 300,
    bg = "white"
  )
}

target_activity <- "Foraging"
species <- "Sparkes_Koala"

# Unlabelled data ---------------------------------------------------------
# load in the files
unlabelled_files <- list.files(file.path(base_path, "CaseStudy", "Sparkes_Koala", "Predictions"), 
                               pattern = "Smoothing_predictions.csv", 
                               full.names = TRUE)
# make the summaries
unlabelled_behavioural_summaries <- summarise_behaviour_sequences(
  unlabelled_files = unlabelled_files,
  target_activity  = target_activity
)
fwrite(unlabelled_behavioural_summaries, file.path(base_path, "CaseStudy", "Sparkes_Koala", paste0("Unlabelled_", target_activity, "_Summries.csv")))

# make the plot
make_smoothing_plot(smoothed_files = unlabelled_files, 
                                     output_name = "Unlabelled"
                                     )
# Labelled data -----------------------------------------------------------
# load in the labelled files
labelled_files <- list.files(file.path(base_path, "Output", "Sparkes_Koala"), 
                                      pattern = "_predictions_", 
                                      full.names = TRUE, recursive = TRUE)
# make the summaries
behavioural_summaries <- summarise_behaviour_sequences(
  unlabelled_files = labelled_files,
  target_activity  = target_activity
)
fwrite(behavioural_summaries, file.path(base_path, "CaseStudy", "Sparkes_Koala", paste0("Labelled_", target_activity, "_Summries.csv")))
       
# make the plot
make_smoothing_plot(smoothed_files = labelled_files, 
                                     output_name = "Labelled"
                                     )
  



# Behavioural budgets -----------------------------------------------------
fill_colours = c(
  "coral", "khaki2", "aquamarine3", "powderblue", "orchid2" )

dt <- lapply(labelled_files, function(x) {
  smoothing_type <- gsub(
    "Smoothing", "",
    stringr::str_split(basename(x), "_")[[1]][1]
  )
  dt <- fread(x) %>% 
    select(any_of(c("ID", "Time", "smoothed_class", "true_class")))
  dt$smoothing_type <- smoothing_type
  dt
})
dt <- rbindlist(dt)
dt <- as.data.frame(dt)

dt$smoothing_type <-factor(dt$smoothing_type,
                           levels = c("TrueClass", "No", "Mode", "Duration", "Transition", "HMM", "Bayesian")
)

budget <- dt %>% 
  group_by(ID, smoothed_class, smoothing_type) %>%
  count()

ggplot(budget, aes(x = smoothing_type, y = n, fill = smoothed_class)) +
  geom_col(position = "stack") +
  facet_wrap(~ID, scale = "free") + 
  my_theme() +
  scale_fill_manual(values = fill_colours)

