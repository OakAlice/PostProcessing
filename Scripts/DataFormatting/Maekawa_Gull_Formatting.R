# Formatting the gull data ------------------------------------------------
# species <- "Maekawa_Gulls"

if (file.exists(file.path(base_path, "Data", species, "Formatted_raw_data.csv"))){
  print("data already formatted")
} else {
  
  data <- fread(file.path(base_path, "Data", species, "raw_data.csv"))
  labels <- fread(file.path(base_path, "Data", species, "labels.csv"))
  
  sample_rate <- 25
  
  # Stitch together ---------------------------------------------------------
  # get the range and give the labels
  data[, timestamp := as.POSIXct(timestamp)]
  labels[, stt_timestamp := as.POSIXct(stt_timestamp)]
  labels[, stp_timestamp := as.POSIXct(stp_timestamp)]
  
  # Prepare for foverlaps:
  # 1. Add 'start' and 'end' to data — same timestamp
  data_overlap <- data[, .(animal_tag, logger_id, acc_x, acc_y, acc_z,
                           start = timestamp, end = timestamp)]
  
  # 2. Add 'start' and 'end' to labels
  labels_overlap <- labels[, .(animal_tag, start = stt_timestamp, end = stp_timestamp,
                               activity, label_id, source)]
  
  # Set keys
  setkey(labels_overlap, animal_tag, start, end)
  setkey(data_overlap, animal_tag, start, end)
  
  # Perform the overlap join
  data_labelled <- foverlaps(data_overlap, labels_overlap, type = "within", nomatch = 0L)
  
  # select only the columns we want
  data_labelled <- data_labelled %>%
    select(animal_tag, activity, acc_x, acc_y, acc_z, i.start) %>%
    rename(ID = animal_tag,
           Activity = activity,
           Time = i.start,
           X = acc_x,
           Y = acc_y,
           Z = acc_z)
  
  fwrite(data_labelled, file.path(base_path, "Data", species, "Formatted_raw_data.csv"))
}
