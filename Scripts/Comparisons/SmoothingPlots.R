# Plots comparing the smoothing effects -----------------------------------
# the same as what we are doing for the case studies but on the labelled data

smoothed_files <- list.files(file.path(base_path, "Output"), 
                             pattern = "_predictions_", 
                             full.names = TRUE, recursive = TRUE)

all_smoothed_data <- lapply(smoothed_files, function(x){
  smoothing_type <- gsub("Smoothing", "", str_split(basename(x), "_")[[1]][1])
  species <- basename(dirname(x))
  dt <- fread(x) %>%
    select(ID, Time, smoothed_class, true_class) %>%
    mutate(Time = as.character(Time),
           smoothing = smoothing_type,
           Species = species)
  dt
})
all_smoothed_data <- rbindlist(all_smoothed_data)
# add in the true labels
true_classes <- all_smoothed_data %>% dplyr::filter(smoothing == "No") %>%
  select(ID, Time, true_class, Species) %>%
  mutate(smoothed_class = true_class,
         smoothing = "TrueClass")
all_smoothed_data <- rbind(all_smoothed_data, true_classes, use.names = TRUE)


all_smoothed_data$smoothing <- factor(all_smoothed_data$smoothing, 
                                      levels = c("TrueClass", "No", "Mode", "Duration", "Transition", "HMM", "Bayesian"))


all_species <- basename(list.dirs(file.path(base_path, "Data"), recursive = FALSE))
for (x in all_species){
  
  plotdata <- all_smoothed_data %>% dplyr::filter(Species == x)
                                                  
  # make a grid plot
  smoothing_plot <- ggplot(plotdata,
         aes(x = Time, y = as.factor(1), fill = as.factor(smoothed_class))) +
    geom_tile() +
    labs(fill = "Activity") +
    my_theme() +
    theme(axis.title = element_blank(), 
          axis.text = element_blank(),
          axis.ticks = element_blank(),
          legend.position = "bottom") +
    scale_fill_manual(values = c(
      "coral", "goldenrod2", "khaki2", "aquamarine3",
      "powderblue", "orchid2", "plum", "lightpink1", 
      "lightcoral", "slateblue3", "thistle3", "sienna1"
    )) +
    facet_grid(
      rows = vars(smoothing),
      cols = vars(ID),
      scales = "free",
      drop = TRUE
    )
  
  ggsave(
    filename = file.path(base_path, "Output", "SmoothingPlots", paste0(x, "_smoothing_plot.png")),
    plot = smoothing_plot,
    width = 40, height = 20,
    units = "cm",
    dpi = 300,
    bg = "white"
  )
  
}
