# Extracting and formatting the Minasandra_Hyena data ---------------------
if (!requireNamespace("BiocManager", quietly = TRUE))
  install.packages("BiocManager")
BiocManager::install("rhdf5")
library(rhdf5)

species <- "Minasandra_Hyena"
files <- list.files(file.path(base_path, "Data", species, "acc"), full.names = TRUE, pattern = "\\.h5$")

library(rhdf5)

accel_data <- lapply(files, function(x) {
  # Read datasets from HDF5
  accel <- h5read(x, "A")
  time  <- h5read(x, "UTC")  # should be a numeric vector of length 6
  
  #extract the static times and string them together
  time_str <- sprintf("%02d/%02d/%04d %02d:%02d:%06.3f", 
                      time[3], time[2], time[1], time[4], time[5], time[6])
  
  init_time <- as.POSIXct(time_str, format = "%d/%m/%Y %H:%M:%OS", tz = "UTC")
  
  # I found I needed to do this
  accel <- as.data.frame(accel)
  
  # incrementing time column
  time_intervals <- 1 / 25  # 25 Hz
  accel$Time <- init_time + seq(0, by = time_intervals, length.out = nrow(accel))
  
  row <- seq(0, by = time_intervals, length.out = nrow(accel))
  
  # and the ID from the file name too
  accel$ID <- str_split(basename(x), "_")[[1]][2]
  
  return(accel)
})

# Combine all files into one data frame
accel_data <- bind_rows(accel_data)

# now get the labels
labels <- list.files(file.path(base_path, "Data", species, "acc"), full.names = TRUE, pattern = "\\.txt$")
label_data <- lapply(labels, function(x){
  data <- fread(labels[x])
  # convert time to a posixct like we do for the matlab data
  data$V1 <- as.POSIXct((data$V1 - 719529)*86400, origin = "1970-01-01", tz = "UTC")
  
})












# Helper to convert character vector to numeric if possible
floatify_list <- function(lst) {
  sapply(lst, function(x) {
    val <- suppressWarnings(as.numeric(x))
    if (is.na(val)) x else val
  }, USE.NAMES = FALSE)
}

# Load audit file: returns list of [timestamp, duration, label]
load_audit_file <- function(filename) {
  lines <- readLines(filename)
  lines <- lines[lines != ""]  # remove blank lines
  
  table <- lapply(lines, function(line) {
    fields <- strsplit(line, "\t")[[1]]
    floatify_list(fields)
  })
  
  # Remove empty rows if any
  table <- Filter(function(x) length(x) > 0, table)
  
  return(table)
}

# Find indices of all SOAs and EOAs
indices_of_audit_starts_and_ends <- function(loaded_audit_file) {
  starts <- which(sapply(loaded_audit_file, function(x) strsplit(as.character(x[3]), " ")[[1]][1] == "SOA"))
  ends   <- which(sapply(loaded_audit_file, function(x) strsplit(as.character(x[3]), " ")[[1]][1] == "EOA"))
  
  if (length(starts) != length(ends)) {
    warning("Unequal number of SOAs and EOAs")
  }
  
  return(list(starts = starts, ends = ends))
}

# Total time audited across all SOA–EOA pairs
total_time_audited <- function(loaded_audit_file) {
  idx <- indices_of_audit_starts_and_ends(loaded_audit_file)
  s <- idx$starts
  e <- idx$ends
  tot_time <- 0
  
  for (i in seq_along(s)) {
    start_time <- as.numeric(loaded_audit_file[[s[i]]][[1]])
    end_time   <- as.numeric(loaded_audit_file[[e[i]]][[1]])
    tot_time <- tot_time + (end_time - start_time)
  }
  
  return(tot_time)
}



audit <- load_audit_file(labels[x])
starts_ends <- indices_of_audit_starts_and_ends(audit)
total <- total_time_audited(audit)
