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

find_suspect_transitions <- function(data, transition_probs_melted, x = 10, threshold = 0.3){
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
  
  prob_data <- data %>%
    left_join(transition_probs_melted, 
              by = c("previous_class" = "First", 
                     "predicted_class" = "Second")) %>%
    mutate(
      likelihood = case_when(
        change_point == 1 & (is.na(Probability) | Probability < threshold) ~ "SUSPICIOUS",
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
train_data <- fread(file.path(base_path, "Data", species, "Feature_data.csv")) %>%
  rename(true_class = Activity)

if (species == "Vehkaoja_Dog"){
  x <- 180 # this one is different time stamps
} else {
  x <- 10 # this is the number of seconds between samples that's counted as a "break"
}

## Check the data ---------------------------------------------------------
# before we use this method, we need to establish how "realistic" our data is
# as in, has it been collected in natural sequence from which we can derive natural sequence probabilities?
# to do this, look at how much of the data is continuous per individual

train_data <- find_breaks(train_data, x = x)

summary <- train_data %>%
  group_by(ID, sequence) %>%
  summarise(sequence_length = length(sequence),
            sequence_behaviours = as.factor(length(unique(true_class))))

# make a distribution frequency plot to geez it (just curiosity)
ggplot(summary, aes(x = sequence_length, fill = sequence_behaviours)) +
   geom_bar(width = 100)

# depending on your dataset there may or may not be a lot of transition sequences to lean from
# you may have to adjust the x value and play around
# just have to use ecological knowledge here...

## Create Transition Matrix ------------------------------------------------
# based on this information, build a likelihood transition between behaviours
# this will be very basic just: given a transition, how probable was that transition?
train_data <- fread(file.path(base_path, "Data", species, "Feature_data.csv")) %>%
  rename(true_class = Activity)

states <- levels(as.factor(train_data$true_class))
n_states <- length(states)

# calculate the transitions
transition_counts <- matrix(0, n_states, n_states, dimnames = list(states, states))
train_data <- train_data %>%
  arrange(ID, Time) %>%
  group_by(ID) %>%
  mutate(next_state = lead(true_class)) %>%
  ungroup()
transitions <- na.omit(train_data[, c("true_class", "next_state")])

# probability of each of these transitions
for (i in seq_len(nrow(transitions))) {
  from <- as.character(transitions$true_class[i])
  to <- as.character(transitions$next_state[i])
  transition_counts[from, to] <- transition_counts[from, to] + 1
}

transition_probs <- prop.table(transition_counts, 1)
transition_probs <- as.data.frame(transition_probs)
transition_probs$First <- rownames(transition_probs)
transition_probs_melted <- transition_probs %>%
  pivot_longer(cols = -First, names_to = "Second", values_to = "Probability")

# I can then use these percentages to assess the validity of the transitions we see in the predictions
## Find all transitions in the predictions data ---------------------------
test_data <- fread(file.path(base_path, "Data", species, "Original_predictions.csv"))

test_data <- find_suspect_transitions(test_data, transition_probs_melted, x = 10, threshold = 0.3)

# TODO: Change the logic of how I modify suspicious events
# for now I'm going with the simple method of denying the transition
# this is overly simple but will do for now
test_data <- update_suspect_transitions(test_data)

## Recalculate performance and save ----------------------------------------
performance <- compute_metrics(as.factor(test_data$smoothed_class), as.factor(test_data$true_class))
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, "TransitionSmoothing_performance.csv"))
generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, "TransitionSmoothing_performance.pdf"))

# Calculate ecological results --------------------------------------------
if (file.exists(file.path(base_path, "Data", species, "Unlabelled_predictions.csv"))){
  
  ecological_data <- fread(file.path(base_path, "Data", species, "Unlabelled_predictions.csv"))
  ecological_data <- find_suspect_transitions(ecological_data, transition_probs_melted, x = 10, threshold = 0.3)
  ecological_data <- update_suspect_transitions(ecological_data)
  
  # calculate what this means
  eco <- ecological_analyses(smoothing_type = "Transition", 
                             eco_data = ecological_data, 
                             target_activity = target_activity)
  question1 <- eco$sequence_summary
  question2 <- eco$hour_proportions
  
  # write these to files
  fwrite(question1, file.path(base_path, "Output", species, "TransitionSmoothing_eco1.csv"))
  fwrite(question2, file.path(base_path, "Output", species, "TransitionSmoothing_eco2.csv"))

} else {
  print("there is no ecological data for this dataset")
}
