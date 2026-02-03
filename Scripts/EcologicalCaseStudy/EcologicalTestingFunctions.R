# Ecological Testing Functions --------------------------------------------
# the other way to test the performance of the model is to see how it answers an 
# ecological question of choice

# I'm not sure what to do with this yet... but will just leave here for now
# can build on this more in future


# have commented out anything I'm not explicitly using 
# was taking way too long with dplyr so had to switch to data.table
# which I am much worse at

ecological_analyses <- function(smoothing_type, eco_data, target_activity) {
    
    dt <- as.data.table(eco_data)
    
    # ensure necessary columns exist
    stopifnot(all(c("ID", "Time", "smoothed_class") %in% names(dt)))
    
    # convert to POSIXct datetime
    dt[, DateTime := as.POSIXct((Time - 719529) * 86400, origin = "1970-01-01", tz = "UTC")]
    
    # summarise in ecologically meaningful ways
    # 1. summarise to most common behaviour per minute
    # minute_summaries <- dt[
    #   , .(Order = .I, MinuteBin = floor_date(DateTime, unit = "minute")),
    #   by = .(ID, Time, smoothed_class)
    # ][
    #   , .SD[which.max(tabulate(match(smoothed_class, unique(smoothed_class))))],
    #   by = .(ID, MinuteBin)
    # ]
    
    # 2. as proportions per hour
    dt[, `:=`(
      Date = date(DateTime),
      Hour = hour(DateTime),
      Behaviour = smoothed_class
    )]
    
    hour_counts <- dt[
      , .N, by = .(ID, Date, Hour, Behaviour)
    ]
    
    total_counts <- dt[
      , .N, by = .(ID, Date, Hour)
    ]
    
    hour_proportions <- merge(
      hour_counts, total_counts,
      by = c("ID", "Date", "Hour"),
      suffixes = c("_behaviour", "_total")
    )[
      , .(ID, Date, Hour, Behaviour, count = N_behaviour,
          total_obs = N_total,
          proportion = round(N_behaviour / N_total, 3),
          smoothing_style = smoothing_type)
    ]
    
    # 3. as number of seuqneces per 24 hours (defined here as 6am - 6am)
    # Order and define sequences
    setorder(dt, ID, DateTime)
    dt[, previous_class := shift(smoothed_class, type = "lag"), by = ID]
    dt[, change_point := fifelse(previous_class != smoothed_class, 1L, 0L)]
    dt[is.na(change_point), change_point := 0L]
    dt[, sequence := cumsum(change_point), by = ID]
    
    # Define 6am-based date bucket
    dt[, day_window := as.Date(DateTime - lubridate::hours(6))]
    
    # Extract target behaviour sequences
    seq_dt <- dt[smoothed_class == target_activity, .(
      behaviour = smoothed_class[1],
      count = .N,
      duration = as.numeric(max(DateTime) - min(DateTime), units = "secs"),
      start_time = min(DateTime)
    ), by = .(ID, sequence)]
    
    # Assign sequences to the corresponding 6am–6am window
    seq_dt[, day_window := as.Date(start_time - lubridate::hours(6))]
    
    # Count how many sequences occur in each 6am–6am window
    daily_seq_counts <- seq_dt[, .N, by = day_window]
    
    # Summarise across days
    sequence_summary <- daily_seq_counts[
      , .(
        mean_frequency = round(mean(N),2),
        sd_frequency = round(sd(N),2),
        smoothing_style = smoothing_type,
        behaviour = target_activity
      )
    ]
    
    sequence_durations <- seq_dt[
      , .(
        mean_duration = round(mean(duration),2),
        sd_duration = round(sd(duration),2)
      )
    ]
    
    summary <- cbind(sequence_summary, sequence_durations)
    
    # return all summaries
    return(list(
      #minute_summaries = minute_summaries,
      hour_proportions = hour_proportions,
      sequence_summary = summary
      # proportions_plot = proportions_plot,
      # sequence_plot = sequence_plot
    ))
  }
  
