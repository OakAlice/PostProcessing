# Script for initialising a markdown report comparing comparisons ---------
# more sieve behaviour - makign this as easy for myself as possible

source(file.path(base_path, "Scripts", "PlottingFunctions.R"))
if (1 == 1) { # change this to be some more helpful condition later lol
  tryCatch({
    # Define the output directory and file
    output_dir <- file.path(base_path, "Output")
    output_file <- paste0("Compare_comparisons.html")
    
    # Knit the r markdown file as an HTML report (has the least errors/dependencies compared to other types of knits)
    rmarkdown::render(
      input = file.path(base_path, "Scripts", "ComparingComparisonsReport.Rmd"),
      output_format = "html_document",
      output_file = output_file,  # File name only
      output_dir = output_dir,   # Directory for saving the file
      params = list( # these are the things I'm going to feed in to change report
        base_path = base_path,
        species = species
      )
    )
    
    # Success message with full path
    message("Comparison of comparisons report saved to: ", file.path(output_dir, output_file))
  }, error = function(e) {
    message("Error in making the comparison of comparisons report: ", e$message)
    stop()
  })
}
