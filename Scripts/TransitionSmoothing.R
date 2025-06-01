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
  group_by(sequence) %>%
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
  



# Find all the break points -----------------------------------------------

test_data <- fread(file.path(base_path, "Data", "StandardisedFormat", paste0(species, "_raw_training_standardised.csv")))



# mark whenever there is a change in behaviour
data <- data %>%
  arrange(ID, Time) %>%
  group_by(ID) %>%
  mutate(
    change_point = ifelse(shift(predicted_class, type = "lag") == predicted_class, 0, 1),
    change_point = replace_na(change_point, 0)
  ) %>%
  ungroup()

# Assess the validity of those changes ------------------------------------
# for every change, assess transition probability
data$smoothed_class <- NA
for (i in 1:length(data$change_point)){
  data$smoothed_class[i] <- data$predicted_class[i] # default set it to be itself
  
  change <- data$change_point[i]
  if (change == 1){
    
    #add code here later
  }
}

# Recalculate performance and save ----------------------------------------
performance <- compute_metrics(data$smoothed_class, data$true_class)
metrics <- performance$metrics
fwrite(metrics, file.path(base_path, "Output", species, "ConfusionSmoothing_performance.csv"))
generate_confusion_plot(performance$conf_matrix_padded, save_path= file.path(base_path, "Output", species, "ConfusionSmoothing_performance.pdf"))


