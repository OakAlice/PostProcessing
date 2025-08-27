# Dataset Characteristics Exploration -------------------------------------

# Functions ---------------------------------------------------------------
# find the breaks
find_breaks <- function(data, x){
  
  ## TODO: Going to have to add a new method for every dataset because they aren't all full datetimes??
  if(is.numeric(data$Time) & data$Time[1] > 719529){
    data <- data %>% mutate(DateTime = as.POSIXct((Time - 719529) * 86400, origin = "1970-01-01", tz = "UTC"))
  } else {
    data$DateTime <- as.POSIXct(data$Time, format = "%Y-%m-%d %H:%M:%OS")
  }
  
  data <- data %>%
    arrange(ID, Time) %>%
    mutate(time_diff = difftime(DateTime, data.table::shift(DateTime)), # had to define package or errored btw
           break_point = ifelse(time_diff > x, 1, 0),
           break_point = replace_na(break_point, 0),
           sequence = cumsum(break_point))
  
  return(data)
}

# Code --------------------------------------------------------------------

characteristics <- list()

for (species in all_species) {
  
  data <- fread(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
  
  if (nrow(data) == 0) {
    message(paste0("No data for ", species))
    next
  }
  
  # Individuals
  individuals <- length(unique(data$ID))
  
  # Behaviour classes
  behaviours <- unique(data$Activity)
  behaviours_string <- if (length(behaviours) == 0) {
    NA_character_
  } else {
    knitr::combine_words(behaviours)
  }
  
  # Sample rate
  sample_rate <- sample_rates[species][[1]]
  
  # Duration annotated (minutes)
  total_duration <- (nrow(data) / sample_rate) / 60
  
  # Measure whether the data is continuous or not
  data <- find_breaks(data, x = 5)
  
  # Metric 1. Transitions
  transitions <- data %>%
    arrange(ID, sequence, Time) %>%
    group_by(ID, sequence) %>%
    mutate(behaviour_change = Activity != lag(Activity)) %>%
    summarise(
      sequence_length = n(),
      n_transitions = sum(behaviour_change, na.rm = TRUE),
      .groups = "drop"
    )
  
  if (nrow(transitions) == 0) {
    mean_transitions_sequence <- NA_real_
    mean_sequence_length <- NA_real_
    median_transitions <- NA_real_
    sd_transitions <- NA_real_
    transition_rate <- NA_real_
  } else {
    mean_transitions_sequence <- mean(transitions$n_transitions)
    mean_sequence_length <- mean(transitions$sequence_length)
    median_transitions <- median(transitions$n_transitions)
    sd_transitions <- sd(transitions$n_transitions)
    transition_rate <- mean(transitions$n_transitions / transitions$sequence_length)
  }
  
  # Metric 2. Multi-behaviour sequences
  multi_behavior <- data %>%
    group_by(ID, sequence) %>%
    summarise(n_behaviours = n_distinct(Activity), .groups = "drop") %>%
    mutate(is_multi = n_behaviours > 1)
  
  prop_multi_sequence <- mean(multi_behavior$is_multi)
  
  # Save into results list
  characteristics[[species]] <- data.frame(
    Species = species,
    Individuals = individuals, 
    Behaviours = behaviours_string, 
    Sample_Rate = sample_rate,
    Duration = round(total_duration,1),
    Mean_Transitions = round(mean_transitions_sequence,1),
    Median_Transitions = round(median_transitions,1),
    Sd_Transitions = round(sd_transitions,1),
    Transition_Rate = round(transition_rate,3),
    Prop_Transitions = round(prop_multi_sequence,1),
    Mean_Seq_Length = round(mean_sequence_length / sample_rate,1)
  )
}

summary_df <- dplyr::bind_rows(characteristics)

fwrite(summary_df, file.path(base_path, "Output", "Dataset_Characteristics.csv"))
