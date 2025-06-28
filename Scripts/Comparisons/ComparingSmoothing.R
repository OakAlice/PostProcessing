# Script for initialising a markdown report comparing smoothings ----------
# because my brain is a sieve, I want to make comparisons as easy as possible
# last year Ryley did some amazing work figuring out how to make automated, interactive markdown reports
# I want to replicate this so I can generate results rapidly

source(file.path(base_path, "Scripts", "PlottingFunctions.R"))
if (1 == 1) { # change this to be some more helpful condition later lol
  tryCatch({
    # Define the output directory and file
    output_dir <- file.path(base_path, "Output", species)
    output_file <- paste0(species, "_compare_smoothing.html")
    
    # Knit the r markdown file as an HTML report (has the least errors/dependencies compared to other types of knits)
    rmarkdown::render(
      input = file.path(base_path, "Scripts", "Comparisons", "ComparingSmoothingReport.Rmd"),
      output_format = "html_document",
      output_file = output_file,  # File name only
      output_dir = output_dir,   # Directory for saving the file
      params = list( # these are the things I'm going to feed in to change report
        base_path = base_path,
        species = species
      )
    )
    
    # Success message with full path
    message("Comparison report saved to: ", file.path(output_dir, output_file))
  }, error = function(e) {
    message("Error in making the comparison report: ", e$message)
    stop()
  })
}
