# Sequential Report -------------------------------------------------------
# how natural is this data, how many transitions are in it?
# Code --------------------------------------------------------------------

all_stats <- data.frame()
for (species in all_species){
  
  species <- basename(species)
    
  data <- fread(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
  
  data <- identify_sequences(data, max_break = ifelse(sample_rates[[species]] > 1, 3, 6)) # based on window duration and buffer
  data <- identify_events(data, class_col = "Activity")
  
  # total number of captured transitions
  total_transitions <- data %>% distinct(ID, sequence, event) %>% nrow()
  
  # mean transitions per sequence
  mean_transitions <- data %>%
    group_by(ID, sequence) %>%
    summarise(transitions = max(event)) %>%
    ungroup() %>%
    summarise(transitions = mean(transitions))
  
  # proportion of sequences that are multi-behaviour
  multi_behaviour <- data %>%
    group_by(ID, sequence) %>%
    summarise(n_behaviours = n_distinct(Activity)) %>%
    mutate(is_multi = n_behaviours > 1) %>%
    ungroup() %>%
    summarise(prop_multi_sequence = mean(is_multi))
  
  # rate of transitions
  transition_rate <- data %>%
    group_by(ID, sequence) %>%
    summarise(transitions = max(event), rows = n()) %>%
    ungroup() %>%
    mutate(rate = transitions / rows) %>%
    summarise(mean_rate = mean(rate))
  
  # mean sequence duration
  mean_seq_duration <- data %>% 
    group_by(ID, sequence) %>%
    count() %>%
    ungroup() %>%
    summarise(mean_seq_len = mean(n))
  
  # save these into the output file for later stats retrieval
  stats_df <- data.frame(
    Species = species,
    total_transitions = as.numeric(total_transitions),
    mean_transitions = as.numeric(mean_transitions$transitions),
    multi_behaviour = as.numeric(multi_behaviour$prop_multi_sequence),
    transition_rate = as.numeric(transition_rate$mean_rate),
    mean_seq_len = as.numeric(mean_seq_duration$mean_seq_len)/sample_rates[[species]],
    Num_IDs = as.numeric(length(unique(data$ID))),
    Num_Activities = as.numeric(length(unique(data$Activity)))
  )

  all_stats <- rbind(all_stats, stats_df)
}

fwrite(all_stats, file.path(base_path, "Output", "All_sequence_stats.csv"))

