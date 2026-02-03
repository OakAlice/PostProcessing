# All the functions for the smoothing methods -----------------------------

# Mode Smoothing Functions ------------------------------------------------
# finding the mode, where x is user defined (so they can change it based on eco context)
rolling_mode_smooth <- function(data, x = 5) {
  stopifnot(x %% 2 == 1)  # ensure odd window
  half_window <- floor(x / 2)
  
  data %>%
    group_by(sequence) %>%
    mutate(
      smoothed_class = {
        v <- predicted_class
        out <- v
        
        if (length(v) < x) {
          # short sequence: replace all by mode
          out <- names(sort(table(v), decreasing = TRUE))[1]
        } else {
          # longer sequence: standard rolling mode
          for (i in (half_window + 1):(length(v) - half_window)) {
            window <- v[(i - half_window):(i + half_window)]
            out[i] <- names(sort(table(window), decreasing = TRUE))[1]
          }
        }
        
        out
      }
    ) %>%
    ungroup()
}

# Transition Functions --------------------------------------------------
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
  chance_threshold <- 1/length(unique(data$predicted_class))
  
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

# Generate Transition probabilities ---------------------------------------
generate_transition_probabilities <- function(train_data){
  
  train_data <- train_data %>%
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
  
  transition_matrix <- prop.table(transition_counts, 1)
  transition_probs <- as.data.frame(transition_matrix)
  transition_probs_melted <- transition_probs %>%
    tibble::rownames_to_column(var = "First") %>%
    pivot_longer(cols = -First, names_to = "Second", values_to = "Probability")
  
  return(list(transition_matrix = transition_matrix,
              transition_probs_melted = transition_probs_melted))
}

# Duration Smoothing Functions --------------------------------------------
smooth_durations <- function(test_data, train_summary, minumum_considered_seq_length, min_rule) {
  
  setDT(test_data)
  setDT(train_summary)
  
  predicted_lengths <- test_data %>%
    group_by(ID, sequence) %>%
    mutate(sequence_length = n()) %>%
    group_by(ID, sequence, event) %>%
    summarise(
      behaviour = first(predicted_class),
      event_length = n(),
      sequence_length = first(sequence_length),
      .groups = "drop"
    ) %>%
    mutate(behaviour = as.character(behaviour))
  
  # flag the ones with issues
  # issues are: the sequence itself is too short
  # the event is the entire duration of the sequence (i.e., we dont have information about true length)
  # the event (inside of a longer sequence) is too short
  predicted_lengths <- predicted_lengths %>%
    left_join(
      train_summary %>% select(behaviour, !!min_rule),
      by = "behaviour"
    ) %>%
    mutate(
      status = case_when(
        sequence_length < minumum_considered_seq_length ~
          "It is what it is",
        
        event_length == sequence_length ~
          "event is the whole sequence, not enough info",
        
        event_length < .data[[min_rule]] ~
          "too short",
        
        TRUE ~ "good"
      )
    )
  
  # Change all the ones that are too short into the most common behaviour in the sequence
  predicted_lengths <- predicted_lengths %>%
    group_by(ID, sequence) %>%
    mutate(
      mode_behaviour = behaviour[which.max(table(behaviour))],
      smoothed_class = if_else(
        status == "too short",
        mode_behaviour,
        behaviour
      )
    ) %>%
    ungroup()
  
  # Merge back to original data
  test_data <- test_data %>%
    left_join(
      predicted_lengths %>%
        select(ID, sequence, event, smoothed_class, status),
      by = c("ID", "sequence", "event")
    )
  
  return(test_data)
}

generate_duration_summaries <- function(train_data){
  # Learn from the training data # these are the lengths in raw samples
  setDT(train_data)
  train_lengths <- train_data[, .(
    behaviour = as.character(true_class[1]),
    length = .N
  ), by = .(ID, sequence, event)]
  
  sequence_lengths <- train_data[, .(
    behaviour = as.character(true_class[1]),
    length = .N
  ), by = .(ID, sequence)] 
  minumum_considered_seq_length <- min(sequence_lengths$length)
  
  # make a distribution of the behaviours
  # ggplot(train_lengths, aes(x = length, fill = behaviour)) +
  #   geom_histogram()
  
  # finding rhe mode as well
  stat_mode <- function(x) {
    ux <- unique(x)
    ux[which.max(tabulate(match(x, ux)))]
  }
  
  # its in raw samples at the moment so need to summarise to windows
  window_samples <- sample_rates[[species]] * ifelse(sample_rates[[species]] > 1, 2, 5)
  train_summary <- train_lengths %>%
    group_by(behaviour) %>%
    summarise(
      min_len= ceiling(min(length)/window_samples),
      mean   = ceiling(mean(length)/window_samples),
      median = ceiling(median(length)/window_samples),
      mode   = ceiling(stat_mode(length)/window_samples),
      p75    = ceiling(quantile(length, 0.25)/window_samples), # longer than 75% of examples
      p95    = ceiling(quantile(length, 0.05)/window_samples), # longer than 95% of examples
      max    = ceiling(max(length)),
      .groups = "drop"
    ) %>% # note that this is measured in windows
    mutate(behaviour = as.character(behaviour))
  
  return(list(train_summary = train_summary,
              minumum_considered_seq_length = minumum_considered_seq_length))
}


# HMM function ------------------------------------------------------------
# make a model from the training data
make_hmm_model <- function(train_data){
  
  train_data$Activity <- train_data$true_class
  transition_matrix <- generate_transition_probabilities(train_data)$transition_matrix
  states <- levels(as.factor(train_data$true_class))
  n_states <- length(states)
  
  # calculate the emission probilities
  observations <- levels(as.factor(train_data$predicted_class))
  n_obs <- length(observations)
  emission_counts <- matrix(0, n_states, n_obs, dimnames = list(states, observations))
  
  for (j in seq_len(nrow(train_data))) {
    hidden <- as.character(train_data$true_class[j])
    observed <- as.character(train_data$predicted_class[j])
    emission_counts[hidden, observed] <- emission_counts[hidden, observed] + 1
  }
  emission_probs <- prop.table(emission_counts, 1)
  
  # make an HMM based off this information
  hmm_model <- initHMM(
    States = states,
    Symbols = observations,
    startProbs = rep(1 / n_states, n_states), # uniform because sampling starts are quite random
    transProbs = transition_matrix,
    emissionProbs = emission_probs
  )
  
  return(hmm_model)
}

# Bayesian ----------------------------------------------------------------
apply_bayes_smoothing <- function(data, states, transition_matrix) {
  
  # sometimes the model predicts fewer classes than are in the training data, and so we get an imbalance
  # these steps are designed to allow the model to function even without all classes predicted
  
  setDT(data)
  
  n_time  <- nrow(data)
  n_class <- length(states)
  
  smoothed_probs <- matrix(0, n_time, n_class)
  colnames(smoothed_probs) <- states
  
  # get the liklihood
  get_likelihood <- function(dt_row, states) {
    lik <- rep(0, length(states))
    names(lik) <- states
    
    present <- intersect(states, names(dt_row))
    lik[present] <- as.numeric(dt_row[, ..present])
    
    lik
  }
  
  prior <- rep(1 / n_class, n_class)
  
  likelihood <- get_likelihood(data[1], states)
  posterior  <- prior * likelihood
  
  if (sum(posterior) == 0) {
    posterior <- prior
  } else {
    posterior <- posterior / sum(posterior)
  }
  
  smoothed_probs[1, ] <- posterior
  
  # do the bayes filter recursivly
  for (t in 2:n_time) {
    
    # prediction step
    prior <- as.numeric(transition_matrix %*% smoothed_probs[t - 1, ])
    
    # update step
    likelihood <- get_likelihood(data[t], states)
    posterior  <- prior * likelihood
    
    if (sum(posterior) == 0) {
      posterior <- prior
    } else {
      posterior <- posterior / sum(posterior)
    }
    
    smoothed_probs[t, ] <- posterior
  }
  
  # put in the sequence
  smoothed_class <- colnames(smoothed_probs)[
    max.col(smoothed_probs, ties.method = "first")
  ]
  
  smoothed_class
}

