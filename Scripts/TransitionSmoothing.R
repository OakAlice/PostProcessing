# Transition Matrix Smoothing ---------------------------------------------
# similar to the confusion method but based on transition probabilities.

train_data <- fread(file.path(base_path, "Data", "StandardisedFormat", paste0(species, "_raw_train_standardised.csv")))
x <- 10 # this is the number of seconds between samples that's counted as a "break"

# Assessing Continuousness ------------------------------------------------
# before we use this method, we need to establish how "realistic" our data is
# as in, has it been collected in natural sequence from which we can derive natural sequence probabilities?
# to do this, look at how much of the data is continuous per individual

train_data <- train_data %>%
  group_by(ID) %>%
  arrange(Time) %>%
  mutate(DateTime = as.POSIXct((Time - 719529)*86400, origin = "1970-01-01", tz = "UTC"),
    time_diff = difftime(DateTime, shift(DateTime, type = "lag")),
    break_point = ifelse(time_diff > x, 1, 0),
    break_point = replace_na(break_point, 0),
    sequence = cumsum(break_point))

summary <- train_data %>%
  group_by(ID, sequence) %>%
  summarise(sequence_length = length(sequence),
            sequence_behaviours = as.factor(length(unique(true_class))))

# make a distribution frequency plot to geez it (just curiosity)
ggplot(summary, aes(x = sequence_length, fill = sequence_behaviours)) +
  geom_bar(width = 5)

# depending on your dataset there may or may not be a lot of transition sequences to lean from
# you may have to adjust the x value and play around
# just have to use ecological knowledge here

# Create Transition Matrix ------------------------------------------------
# based on this information, build a likelihood transition between behaviours
# this will be very basic just: given a transition, how probable was that transition?

# find the break points and record how they transitioned as a %
transitions <- train_data %>%
  group_by(ID, sequence) %>%
  mutate(
    previous_class = shift(true_class, type = "lag"),
    change_point = ifelse(previous_class != true_class, 1, 0),
    change_point = replace_na(change_point, 0)
  ) %>%
  filter(change_point == 1) %>%
  select(sequence, previous_class, true_class) %>%
  ungroup()
# sometimes I do this to take a breather from piping for readability sake
transitions <- transitions %>%
  group_by(previous_class, true_class) %>%
  summarise(count = n(), .groups = "drop") %>%
  group_by(previous_class) %>%
  mutate(
    proportion = count / sum(count)
  ) %>%
  rename(followed_by = true_class)




############## replace the above code with the following: ######
train_data <- train_data %>% group_by(true_class) %>% slice_head(n = 200) %>% ungroup()

states <- levels(train_data$true_class)
n_states <- length(states)

transition_counts <- matrix(0, n_states, n_states, dimnames = list(states, states))
train_data <- train_data %>%
  arrange(ID, Time) %>%
  group_by(ID) %>%
  mutate(next_state = lead(true_class)) %>%
  ungroup()

transitions <- na.omit(train_data[, c("true_class", "next_state")])

for (i in seq_len(nrow(transitions))) {
  from <- as.character(transitions$true_class[i])
  to <- as.character(transitions$next_state[i])
  transition_counts[from, to] <- transition_counts[from, to] + 1
}

# Convert to probabilities
transition_probs <- prop.table(transition_counts, 1)
#################### it is better ############################





# I can then use these percentages to assess the validity of the transitions we see in the predictions

# Find all transitions in the predictions data ----------------------------
test_data <- fread(file.path(base_path, "Data", "StandardisedFormat", paste0(species, "_test_data.csv")))

test_data <- test_data %>%
  group_by(ID) %>%
  arrange(Time) %>%
  mutate(DateTime = as.POSIXct((Time - 719529)*86400, origin = "1970-01-01", tz = "UTC"),
         time_diff = difftime(DateTime, shift(DateTime, type = "lag")),
         break_point = ifelse(time_diff > x, 1, 0),
         break_point = replace_na(break_point, 0),
         sequence = cumsum(break_point)) %>%
  group_by(ID, sequence) %>%
  mutate(
    previous_class = shift(predicted_class, type = "lag"),
    change_point = ifelse(previous_class != predicted_class, 1, 0),
    change_point = replace_na(change_point, 0)
  )

# Check each of the transitions probability -------------------------------
threshold <- 0.3  # user-defined probability threshold
test_data <- test_data %>%
  left_join(transitions, 
            by = c("previous_class" = "previous_class", 
                   "predicted_class" = "followed_by")) %>%
  mutate(
    likelihood = case_when(
      change_point == 1 & (is.na(proportion) | proportion < threshold) ~ "SUSPICIOUS",
      TRUE ~ "ACCEPTABLE"
    )
  ) %>%
  ungroup() %>%
  select(!c("break_point", "previous_class", "change_point", "count")) # clean it up

# Change the suspicious events --------------------------------------------
# TODO: Change the logic of how I modify suspicious events
# for now I'm going with the simple method of denying the transition
# this is dumb and overly simple but will do for now

test_data <- test_data %>%
  mutate(smoothed_class = ifelse(likelihood == "ACCEPTABLE", predicted_class, NA)
  ) %>%
  group_by(ID, sequence) %>% 
  fill(smoothed_class, .direction = "down") %>%
  ungroup()

# Recalculate performance and save ----------------------------------------
performance <- compute_metrics(test_data$smoothed_class, test_data$true_class)
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, "TransitionSmoothing_performance.csv"))
generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, "TransitionSmoothing_performance.pdf"))
