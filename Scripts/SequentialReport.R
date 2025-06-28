# Sequential Report -------------------------------------------------------
# how natural is this data, how many transitions are in it?

# load in the data
train_data <- fread(file.path(base_path, "Data", species, "Feature_data.csv"))

# find the breaks
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

# find all the breaks in sequential reports
train_data <- find_breaks(train_data, x = 5)

summary <- train_data %>%
  group_by(ID, sequence) %>%
  summarise(sequence_length = length(sequence),
            sequence_behaviours = as.factor(length(unique(Activity))))

# make a distribution frequency plot to geez it (just curiosity)
ggplot(summary, aes(x = sequence_length, fill = sequence_behaviours)) +
  geom_bar(width = 5)

# depending on your dataset there may or may not be a lot of transition sequences to lean from
# you may have to adjust the x value and play around
# just have to use ecological knowledge here...
