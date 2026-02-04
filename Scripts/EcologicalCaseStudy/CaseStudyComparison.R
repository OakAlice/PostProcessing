# Ecological Testing Functions --------------------------------------------
# the other way to test the performance of the model is to see how it answers an 
# ecological question of choice


# Here I will compare questions about the behavioural profile of the case study dataset
# when using the different post-processing methods.
# load in the different datasets
smoothed_files <- list.files(file.path(base_path, "CaseStudy", species, "Predictions"), 
                             pattern = "Smoothing_predictions.csv", 
                             full.names = TRUE)

target_activity <- ifelse(species == "Sparkes_Koala", "Locomotion", "3")
  
behavioural_summaries <- lapply(smoothed_files, function(x){
  
  smoothing_type <- gsub("Smoothing", "", str_split(basename(x), "_")[[1]][1])
  
  dt <- fread(x) %>%
    select(ID, Time, sequence, smoothed_class)
  setDT(dt)

  # as number of seuqneces per ID
  # Order and define sequences
  setorder(dt, ID, Time)
  dt[, previous_class := shift(smoothed_class, type = "lag"), by = ID]
  dt[, change_point := fifelse(previous_class != smoothed_class, 1L, 0L)]
  dt[is.na(change_point), change_point := 0L]
  dt[, sequence := cumsum(change_point), by = ID]

  # Extract target behaviour sequences
  seq_dt <- dt[smoothed_class == target_activity, .(
    behaviour = smoothed_class[1],
    count = .N,
    duration = as.numeric(max(Time) - min(Time), units = "secs"),
    start_time = min(Time)
  ), by = .(ID, sequence)]
  
  # Count how many sequences occur for each ID
  daily_seq_counts <- seq_dt[, .N, by = ID]
  
  # Summarise across days
  sequence_summary <- daily_seq_counts[
    , .(
      mean_frequency = round(mean(N),2),
      sd_frequency = round(sd(N),2),
      smoothing_style = smoothing_type,
      behaviour = target_activity
    )
  ]
  
  sequence_durations <- seq_dt[
    , .(
      mean_duration = round(mean(duration),2),
      sd_duration = round(sd(duration),2)
    )
  ]
  
  summary <- cbind(sequence_summary, sequence_durations)
  summary
})
behavioural_summaries <- rbindlist(behavioural_summaries)


# making the comparison plot
behavioural_plotdt <- lapply(smoothed_files, function(x){
  smoothing_type <- gsub("Smoothing", "", str_split(basename(x), "_")[[1]][1])
  dt <- fread(x) %>%
    select(ID, Time, sequence, smoothed_class) %>%
    mutate(smoothing = smoothing_type)
  dt
})
behavioural_plotdt <- rbindlist(behavioural_plotdt)
behavioural_plotdt$smoothing <- factor(behavioural_plotdt$smoothing, 
                                       levels = c("No", "Mode", "Duration", "Transition", "HMM", "Bayesian"))
plotdata <- behavioural_plotdt #%>% dplyr::filter(smoothing == "Bayesian", ID == "Angelina")

# make a grid plot
# should be fill but that wasn't working so had to use colour as a work around 
casestudy_smooths <- ggplot(plotdata,
                            aes(x = Time, y = as.factor(1), colour = as.factor(smoothed_class))) +
  geom_tile() +
  labs(colour = "Activity") +
  my_theme() +
  theme(axis.title = element_blank(), 
        axis.text = element_blank(),
        axis.ticks = element_blank(),
        legend.position = "bottom") +
  scale_colour_manual(values = c(
    "coral", "goldenrod2", "khaki2", "aquamarine3",
    "powderblue", "orchid2", "plum", "lightpink1", 
    "lightcoral", "slateblue3", "thistle3", "sienna1"
  )) +
  facet_grid(
    rows = vars(smoothing),
    cols = vars(ID),
    scales = "free",
    drop = TRUE
  )

ggsave(
  filename = file.path(base_path, "CaseStudy", species, "CaseStudy_smoothing_plot.png"),
  plot = casestudy_smooths,
  width = 40, height = 20,
  units = "cm",
  dpi = 300,
  bg = "white"
)
