# Rendering the R markdown ------------------------------------------------
if (1 == 1) {
    tryCatch({
      # Define the output directory and file
      output_dir <- file.path(base_path, "Plots")
      output_file <- "Koala_data_exploration.html"
      
      # Knit the VisulisationReport.Rmd file as an HTML report
      rmarkdown::render(
        input = file.path(base_path, "Scripts", "KoalaDataVisualisationReport.Rmd"),
        output_format = "html_document",
        output_file = output_file,  # File name only
        output_dir = output_dir,   # Directory for saving the file
        #clean = TRUE,
        quiet = TRUE,
        params = list(
          base_path = base_path,
          sample_rate = sample_rate,
          n_samples = 300,
          n_col = 4,
          window_length = window_length,
          overlap_percent = overlap_percent,
          minimum_distance = 0.4,
          shape_metric= "euclidean",
          num_neighbours=20,
          samples_to_analyse = 2000
        )
      )
      
      # Success message with full path
      message("Exploration report saved")
    }, error = function(e) {
      message("Error in making the data exploration report: ", e$message)
      stop()
    })
}
