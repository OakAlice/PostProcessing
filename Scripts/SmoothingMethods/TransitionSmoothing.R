# Transition Matrix Smoothing ---------------------------------------------
# similar to the confusion method but based on transition probabilities.

# Functions ---------------------------------------------------------------
find_suspect_transitions <- function(data, transition_probs_melted){
  data <- data %>%
    group_by(ID, sequence) %>%
    mutate(
      previous_class = data.table::shift(predicted_class, type = "lag"),
      next_class = data.table::shift(predicted_class, type = "lead"),
      change_point = ifelse(previous_class != predicted_class, 1, 0),
      change_point = replace_na(change_point, 0)
    ) %>%
    mutate(predicted_class = as.factor(predicted_class),
           previous_class = as.factor(previous_class),
           next_class = as.factor(next_class))
  
  # define the threshold at which probability is accepted based on chance rate
  chance_threshold <- 1/length(unique(data$true_class))
  
  # apply this
  # logic here is that if it is different from both the preceeding and succeeding classes
  # and there is a low probability of that transition occuring in the training data (below chance)
  # then flag it as suspicious event
  prob_data <- data %>%
    left_join(
      transition_probs_melted,
      by = c(
        "previous_class"  = "First",
        "predicted_class" = "Second"
      )
    ) %>%
    mutate(
      likelihood = case_when(
        change_point == 1 &
          predicted_class != previous_class &
          predicted_class != next_class &
          (is.na(Probability) | Probability < chance_threshold) ~
          "SUSPICIOUS",
        TRUE ~ "ACCEPTABLE"
      )
    )
  
  return(prob_data)
}

update_suspect_transitions <- function(data, transition_probs_melted){
  # logic for this update is to change the suspicious transition to the most probable other activity
  # which is calculated as prediction confidence x transition probability
  
    # find the second most likely prediction and see whether that would be better
    prob_cols <- names(data)[
      (match("Time", names(data)) + 1):(match("predicted_class", names(data)) - 1)
    ]
    
    data <- data %>%
      rowwise() %>%
      mutate(
        second_prob = {
          probs <- c_across(all_of(prob_cols))
          ord <- order(probs, decreasing = TRUE, na.last = NA)
          if (length(ord) < 2) NA_character_
          else prob_cols[ord[2]]
        }
      ) %>%
      ungroup()
    
    # calculate the transition probability for the second most likely class
    prob_data <- data %>%
      left_join(
        transition_probs_melted,
        by = c(
          "previous_class" = "First",
          "second_prob"    = "Second"
        )
      ) 
    
    # select the more likely of them as the smoothed_class
    prob_data <- prob_data %>%
      mutate(
        smoothed_class = case_when(
          likelihood == "ACCEPTABLE" ~ predicted_class,
          likelihood != "ACCEPTABLE" & Probability.y > Probability.x ~ second_prob,
          TRUE ~ predicted_class
        )
      ) %>%
      select(-c(previous_class, next_class, change_point,
                Probability.x,  likelihood, second_prob, Probability.y))
    
    return(prob_data)
    
  }

# Code --------------------------------------------------------------------
## Create Transition Matrix ------------------------------------------------
# based on this information, build a likelihood transition between behaviours
# this will be very basic just: given a transition, how probable was that transition?
train_data <- fread(file.path(base_path, "Data", species, "Formatted_raw_data.csv")) %>%
  arrange(ID, Time)
train_data <- identify_sequences(train_data, max_break = ifelse(sample_rates[[species]] > 1, 3, 6)) # based on window duration and buffer

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
  to <- as.character(transitions$next_state[j])
  transition_counts[from, to] <- transition_counts[from, to] + 1
}

transition_probs <- prop.table(transition_counts, 1)
transition_probs <- as.data.frame(transition_probs)
transition_probs$First <- rownames(transition_probs)
transition_probs_melted <- transition_probs %>%
  pivot_longer(cols = -First, names_to = "Second", values_to = "Probability")

# I can then use these percentages to assess the validity of the transitions we see in the predictions
## Find all transitions in the predictions data ---------------------------
test_data <- fread(file.path(base_path, "Data", species, paste0("Original_predictions_", i, ".csv"))) %>%
  arrange(ID, Time)
test_data <- identify_sequences(test_data, max_break = ifelse(sample_rates[[species]] > 1, 3, 6)) # based on window duration and buffer

test_data <- find_suspect_transitions(test_data, transition_probs_melted)

# logic of how these are then updated and changed:
# if the transition is unlikely, choose the next most probable class it could have been
# and see whether that one is more likely 
test_data <- update_suspect_transitions(test_data, transition_probs_melted)

## Recalculate performance and save ----------------------------------------
performance <- compute_metrics(as.factor(test_data$smoothed_class), as.factor(test_data$true_class))
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, paste0("TransitionSmoothing_performance_", i, ".csv")))
# generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, paste0("TransitionSmoothing_performance_", i, ".pdf")))
