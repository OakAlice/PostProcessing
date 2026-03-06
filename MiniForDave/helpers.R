# Plotting functions and settings -----------------------------------------

# Custom theme ------------------------------------------------------------
my_theme <- function() {
  theme_minimal(base_size = 12) +
    theme(
      panel.border = element_rect(color = "black", linewidth = 1.5, fill = NA),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      plot.background = element_blank(),
      panel.background = element_blank(),
      axis.line = element_line(color = "black"),
      axis.ticks = element_line(color = "black")
    )
}

# Colours -----------------------------------------------------------------
my_colours = c("grey37",
               "coral", 
               "goldenrod2", 
               "khaki2", 
               "aquamarine3", 
               "powderblue", 
               "plum", 
               "lightpink1")
names(my_colours) <- c("No", 
                       "Mode", 
                       "Duration", 
                       "Transition", 
                       "HMM", 
                       "Bayesian", 
                       "LSTM")

