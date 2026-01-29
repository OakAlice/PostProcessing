# Finding unique sequences and events --------------------------------------
# This script will become unnecessary once Ethan and I have updated all the datasets
# but for now I need it to find the sequences and events for each smoothing method to work inside of

identify_sequences <- function(data, max_break = 1){
  
  if(species == "Dunford_Cat"){
    data <- data %>%
      group_by(ID) %>%
      mutate(
        time_sec = as.numeric(
          strptime(Time, format = "%H:%M:%S", tz = "UTC")
        ),
        day_offset = cumsum(c(0, diff(time_sec) < 0)),
        numeric_datetime = day_offset * 86400 + time_sec,
        Time = as.POSIXct(
          numeric_datetime,
          origin = "1970-01-01",
          tz = "UTC"
        )
      ) %>%
      ungroup() %>%
      select(-time_sec, -day_offset, -numeric_datetime)
  }
  
  
  data <- data %>%
    group_by(ID) %>%
    arrange(Time, .by_group = TRUE) %>%
    mutate(time_diff = difftime(Time, data.table::shift(Time)), # had to define package or errored
           break_point = ifelse(time_diff > max_break | time_diff < 0 , 1, 0),
           break_point = replace_na(break_point, 0),
           sequence = cumsum(break_point)) %>%
    select(-break_point, -time_diff) %>%
    ungroup()
    
  return(data)
  
}

identify_events <- function(data, class_col = "true_class"){
  
  class_sym <- sym(class_col)
  
  data <- data %>%
    group_by(ID, sequence) %>%
    arrange(Time, .by_group = TRUE) %>%
    mutate(
      change_point = if_else(lag(!!class_sym) == !!class_sym, 0L, 1L),
      change_point = replace_na(change_point, 0L),
      event = cumsum(change_point)
    ) %>%
    ungroup() %>%
    select(-change_point)
  
  return(data)
}
  