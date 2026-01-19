# Sequential Report -------------------------------------------------------
# how natural is this data, how many transitions are in it?

# Functions ---------------------------------------------------------------
# find the breaks
find_breaks <- function(data, species){
  
  # Had to define a new method for nearly every dataset because they aren't all full datetime
  
  if (species == "Clemente_Echidna"){
    data <- data %>%
      arrange(ID, Time) %>%
      mutate(time_diff = difftime(Time, data.table::shift(Time)), # had to define package or errored btw
             break_point = ifelse(time_diff > 0.2, 1, 0),
             break_point = replace_na(break_point, 0),
             sequence = cumsum(break_point))
    
  } else if (species == "Dunford_Cat"){
    data <- data %>%
      group_by(ID) %>%
      mutate(
        time_sec = as.numeric(
          strptime(Time, format = "%H:%M:%S", tz = "UTC")
        ),
        day_offset = cumsum(c(0, diff(time_sec) < 0)),
        numeric_datetime = day_offset * 86400 + time_sec,
        Time = as.POSIXct(
          numeric_datetime,
          origin = "1970-01-01",
          tz = "UTC"
        )
      ) %>%
      select(-c("time_sec", "day_offset", "numeric_datetime")) %>%
      ungroup() %>%
      arrange(ID, Time) %>%
      mutate(time_diff = difftime(Time, data.table::shift(Time)), # had to define package or errored btw
             break_point = ifelse(time_diff > 2, 1, 0),
             break_point = replace_na(break_point, 0),
             sequence = cumsum(break_point))
    
  } else if (species == "Ferdinandy_Dog"){
    data <- data %>%
      arrange(ID, Time) %>%
      mutate(time_diff = as.numeric(Time) - lag(as.numeric(Time)),
             break_point = ifelse(time_diff > 2, 1, 0),
             break_point = replace_na(break_point, 0),
             sequence = cumsum(break_point))
  } else if (species == "Ladds_Seal"){
    data <- data %>%
      mutate(Time = as.POSIXct(Time, format = "%Y-%m-%d %H:%M:%OS")) %>%
      arrange(ID, Time) %>%
      mutate(time_diff = difftime(Time, data.table::shift(Time)),
             break_point = ifelse(time_diff > 2, 1, 0),
             break_point = replace_na(break_point, 0),
             sequence = cumsum(break_point))
    
  } else if (species == "Vehkaoja_Dog"){
    data <- data %>%
      arrange(ID, Time) %>%
      mutate(time_diff = Time - lag(Time),
             break_point = ifelse(time_diff > 2, 1, 0),
             break_point = replace_na(break_point, 0),
             sequence = cumsum(break_point))
    
  } else if (species %in% c("Desantis_Rattlesnake", "Galea_Cat", "HarveyCaroll_Pangolin",
                     "Maekawa_Gull", "Mauny_Goat", "Pagano_Bear", "Smit_Cat",
                     "Sparkes_Koala", "Studd_Squirrel", "Yu_Duck")){
    data <- data %>%
      arrange(ID, Time) %>%
      mutate(time_diff = difftime(Time, data.table::shift(Time)), # had to define package or errored btw
             break_point = ifelse(time_diff > 2, 1, 0),
             break_point = replace_na(break_point, 0),
             sequence = cumsum(break_point))
  
  }
  
  return(data)
}

# Code --------------------------------------------------------------------

all_stats <- data.frame()
for (species in all_species){
  
  species <- basename(species)
    
  data <- fread(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
  
  # find all the breaks in sequential reports
  train_data <- find_breaks(data, species)
  
  # metric 1. mean transitions per sequence
  transitions <- train_data %>%
    arrange(ID, sequence, Time) %>%
    group_by(ID, sequence) %>%
    mutate(behaviour_change = Activity != lag(Activity)) %>%
    summarise(
      sequence_length = n(),
      n_transitions = sum(behaviour_change, na.rm = TRUE)
    )
  
  mean_transitions_sequence <- mean(transitions$n_transitions)
  mean_sequence_length <- mean(transitions$sequence_length)
  median_transitions <- median(transitions$n_transitions)
  sd_transitions <- sd(transitions$n_transitions)
  
  # and the rate at which they change
  transition_rate <- mean(transitions$n_transitions / transitions$sequence_length)
  
  # metric 2. proportion of sequences that are multi-behaviour
  multi_behavior <- train_data %>%
    group_by(ID, sequence) %>%
    summarise(n_behaviours = n_distinct(Activity)) %>%
    mutate(is_multi = n_behaviours > 1)
  
  summary_stats <- multi_behavior %>%
    summarise(prop_multi_sequence = mean(is_multi))
  
  # save these into the output file for later stats retrieval
  stats_df <- data.frame(
    Species = species,
    Mean_Transitions = as.numeric(mean_transitions_sequence),
    Median_Transitions = as.numeric(median_transitions),
    Sd_Transitions = as.numeric(sd_transitions),
    Transition_Rate = as.numeric(transition_rate),
    Prop_Transitions = mean(summary_stats$prop_multi_sequence),
    Mean_Seq_Length = as.numeric(mean_sequence_length),
    Num_Activities = as.numeric(length(unique(data$Activity)))
  )

  all_stats <- rbind(all_stats, stats_df)
}

fwrite(all_stats, file.path(base_path, "Output", "All_sequence_stats.csv"))

