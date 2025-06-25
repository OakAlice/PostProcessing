# Formatting the echidna data ---------------------------------------------

# this is going to be hard because not only is the data weirdly in matlab
# I'm not even sure which files the data is


# Get the files out of matlab ---------------------------------------------
install.packages("R.matlab")
library(R.matlab)

input_dir <- "R:/FSHEE/Science/Unsupervised-Accel/Echidna data/echidna analysis" # they are stored here
output_dir <- "R:/FSHEE/Science/Unsupervised-Accel/Echidna data/Raw_data"

mat_files <- list.files(input_dir, pattern = "\\.mat$", full.names = TRUE)

for (file in mat_files) {
  data <- readMat(file)
  if ("Time.Acc.Temp.Activity.Mat.Scored" %in% names(data)) {
    df <- data[["Time.Acc.Temp.Activity.Mat.Scored"]]
    if (is.matrix(df) || is.data.frame(df)) {
      out_file <- file.path(output_dir,
                            paste0(tools::file_path_sans_ext(basename(file)), "_Extracted.csv"))
      write.csv(df, out_file, row.names = FALSE)
    }
  }
}

# move them to the post-processing work folder ----------------------------

# Format them -------------------------------------------------------------

