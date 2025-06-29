# Sequential Report -------------------------------------------------------
# how natural is this data, how many transitions are in it?

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
# load in the data
train_data <- fread(file.path(base_path, "Data", species, "Feature_data.csv"))
# find all the breaks in sequential reports
train_data <- find_breaks(train_data, x = 5)

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
  Mean_Seq_Length = as.numeric(mean_sequence_length)
)

fwrite(stats_df, file.path(base_path, "Output", species, "Sequence_stats.csv"))
