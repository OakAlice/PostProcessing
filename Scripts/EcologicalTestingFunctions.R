# Ecological Testing Functions --------------------------------------------
# the other way to test the performance of the model is to see how it answers an 
# ecological question of choice

# I'm not sure what to do with this yet... but will just leave here for now
# can build on this more in future

ecological_analyses <- function(smoothing_type, test_data, target_activity){
  
  # summarise in ecologically meaningful ways
  # 1. summarise to most common behaviour per minute
  minute_summaries <- test_data %>%
    as.data.frame() %>%
    dplyr::select(ID, Time, true_class, smoothed_class) %>%
    group_by(ID) %>%
    mutate(DateTime = as.POSIXct((Time - 719529)*86400, origin = "1970-01-01", tz = "UTC"),
      MinuteBin = floor_date(DateTime, unit = "minute"),
      Order = row_number()) %>%
    group_by(ID, Order, MinuteBin) %>%
    summarise(behaviour = names(sort(table(smoothed_class), decreasing = TRUE))[1])
  
  # 2. as proportions per hour
  hour_proportions <- test_data %>%
    as.data.frame() %>%
    dplyr::select(ID, Time, true_class, smoothed_class) %>%
    mutate(DateTime = as.POSIXct((Time - 719529)*86400, origin = "1970-01-01", tz = "UTC"),
           Date = date(DateTime), Hour = hour(DateTime), Behaviour = smoothed_class) %>%
    group_by(ID, Date, Hour) %>%
    mutate(total_obs = n()) %>%
    group_by(ID, Date, Hour, Behaviour, total_obs) %>%
    summarise(count = n()) %>%
    mutate(proportion = round(count/total_obs,3))
  
  # 3. as sequences of behaviour
  sequence_summary <- test_data %>%
    dplyr::select(ID, Time, true_class, smoothed_class) %>%
    mutate(DateTime = as.POSIXct((Time - 719529)*86400, origin = "1970-01-01", tz = "UTC")) %>%
    group_by(ID) %>%
    arrange(DateTime) %>%
    mutate(
      previous_class = shift(smoothed_class, type = "lag"),
      change_point = ifelse(previous_class != smoothed_class, 1, 0),
      change_point = replace_na(change_point, 0),
      sequence = cumsum(change_point)
    ) %>%
    group_by(ID, sequence) %>%
    summarise(behaviour = smoothed_class[1], count = n(), duration = difftime(max(DateTime), min(DateTime))) %>%
    filter(behaviour == target_activity) %>%
    ungroup() %>%
    summarise(frequency = n(), average_duration = round(mean(duration),2)) %>%
    mutate(smoothing_style = smoothing_type, behaviour = target_activity)

  # and make an ecological plot
  # I haven't settled on a method yet so have options here... can add differnt stuff or do them all
  
  # proportions through the day
  proportions_plot <- ggplot(data = hour_proportions, aes(x = Hour, y = proportion, colour = Behaviour)) +
    geom_point() +
    geom_smooth(alpha = 0.2, se = FALSE) +
    my_theme() +
    labs(x = "Hour", y = "Proportion of each hour")
  
  # most common behaviour per minute
  sequence_plot <- ggplot(data = minute_summaries, aes(x = Order, y = ID, fill = behaviour)) +
    geom_tile()
  
  return(list(minute_summaries = minute_summaries,
              hour_proportions = hour_proportions,
              sequence_summary = sequence_summary,
              proportions_plot = proportions_plot,
              sequence_plot = sequence_plot))
  
}
