# Transition Matrix Smoothing ---------------------------------------------
# similar to the confusion method but based on transition probabilities.

# Functions ---------------------------------------------------------------
find_breaks <- function(data, x){
  
  ## TODO: Going to have to add a new method for every dataset because they aren't all full datetimes
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

find_suspect_transitions <- function(data, transition_probs_melted, x = 10){
  data <- find_breaks(data, x)
  data <- data %>%
    group_by(ID, sequence) %>%
    mutate(
      previous_class = data.table::shift(predicted_class, type = "lag"),
      change_point = ifelse(previous_class != predicted_class, 1, 0),
      change_point = replace_na(change_point, 0)
    ) %>%
    mutate(predicted_class = as.factor(predicted_class),
           previous_class = as.factor(previous_class))
  
  # define the threshold at which probability is accepted based on changce rate
  chance_threshold <- 1/length(unique(data$true_class))
  
  # apply this
  prob_data <- data %>%
    left_join(transition_probs_melted, 
              by = c("previous_class" = "First", 
                     "predicted_class" = "Second")) %>%
    mutate(
      likelihood = case_when(
        change_point == 1 & (is.na(Probability) | Probability < 2 * chance_threshold) ~ "SUSPICIOUS",
        TRUE ~ "ACCEPTABLE"
      )
    ) %>%
    ungroup()
  
  return(prob_data)
}

update_suspect_transitions <- function(data){
  # this is fine for now but I could much improve this logic 
  # have made into a function so easy to change later
  data <- data %>%
    mutate(smoothed_class = ifelse(likelihood == "ACCEPTABLE", predicted_class, NA)
    ) %>%
    group_by(ID, sequence) %>% 
    fill(smoothed_class, .direction = "down") %>%
    ungroup()
  
  return(data)
}

# Code --------------------------------------------------------------------
if (species == "Vehkaoja_Dog"){
  x <- 180 # this one is different time stamps
} else {
  x <- 10 # this is the number of seconds between samples that's counted as a "break"
}

## Create Transition Matrix ------------------------------------------------
# based on this information, build a likelihood transition between behaviours
# this will be very basic just: given a transition, how probable was that transition?
train_data <- fread(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
train_data <- identify_sequences(train_data, max_break = ifelse(sample_rates[[species]] > 1, 2.5, 5.5)) # based on window duration and buffer
train_data <- identify_events(train_data, class_col = "Activity")

states <- levels(as.factor(train_data$Activity))
n_states <- length(states)

# calculate the transitions within continuous sequences
transition_counts <- matrix(0, n_states, n_states, dimnames = list(states, states))
train_data <- train_data %>%
  group_by(ID, sequence) %>%
  arrange(Time, .by_group = TRUE) %>%
  mutate(next_state = lead(Activity)) %>%
  ungroup()
transitions <- na.omit(train_data[, c("Activity", "next_state")]) # remove the ones that are last in sequence

# probability of each of these transitions
for (j in seq_len(nrow(transitions))) {
  from <- as.character(transitions$Activity[j])
  to <- as.character(transitions$Activity[j])
  transition_counts[from, to] <- transition_counts[from, to] + 1
}

transition_probs <- prop.table(transition_counts, 1)
transition_probs <- as.data.frame(transition_probs)
transition_probs$First <- rownames(transition_probs)
transition_probs_melted <- transition_probs %>%
  pivot_longer(cols = -First, names_to = "Second", values_to = "Probability")



# I can then use these percentages to assess the validity of the transitions we see in the predictions
## Find all transitions in the predictions data ---------------------------
test_data <- fread(file.path(base_path, "Data", species, paste0("Original_predictions_", i, ".csv")))

test_data <- find_suspect_transitions(test_data, transition_probs_melted, x = 10)

# TODO: Change the logic of how I modify suspicious events
# for now I'm going with the simple method of denying the transition
# this is overly simple but will do for now
test_data <- update_suspect_transitions(test_data)

## Recalculate performance and save ----------------------------------------
performance <- compute_metrics(as.factor(test_data$smoothed_class), as.factor(test_data$true_class))
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, paste0("TransitionSmoothing_performance_", i, ".csv")))
# generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, paste0("TransitionSmoothing_performance_", i, ".pdf")))
