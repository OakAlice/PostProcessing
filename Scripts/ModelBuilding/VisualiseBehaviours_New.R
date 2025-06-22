
# Visualise behavioural clusters ------------------------------------------
# functions and then executions


# Functions ---------------------------------------------------------------
plotTraceExamples <- function(behaviours, data, individuals, n_samples, n_col) {
  
  data <- data %>% filter(ID %in% sample(unique(data$ID), individuals))
  
  # Create plots for each behavior (with error catching)
  plots <- purrr::map(behaviours, function(behaviour) {
    tryCatch(
      {
        plot_behaviour(behaviour, n_samples, data)
      },
      error = function(e) {
        message("Skipping plot for ", behaviour, ": ", e$message)
        NULL  # Return NULL to indicate skipping
      }
    )
  })
  
  # Remove NULL plots (for behaviors with no data)
  plots <- purrr::compact(plots)
  
  # Combine plots into a single grid
  grid_plot <- cowplot::plot_grid(plotlist = plots, ncol = n_col)
  
  return(list(plots = plots, 
                 grid_plot = grid_plot))
}

# Function to create the plot for each behavior
plot_behaviour <- function(behaviour, n_samples, data) {
  df <- data %>%
    filter(Activity == behaviour) %>%
    group_by(ID, Activity) %>%
    slice(1:n_samples) %>%
    mutate(relative_time = row_number())
  
  # Check if the filtered dataframe is empty
  if (nrow(df) == 0) {
    stop("No data available for behaviour: ", behaviour)
  }
  
  ggplot(df, aes(x = relative_time)) +
    geom_line(aes(y = Accelerometer.X, color = "X"), show.legend = FALSE) +
    geom_line(aes(y = Accelerometer.Y, color = "Y"), show.legend = FALSE) +
    geom_line(aes(y = Accelerometer.Z, color = "Z"), show.legend = FALSE) +
    labs(title = paste(behaviour),
         x = NULL, y = NULL) +
    scale_color_manual(values = c(X = "salmon", Y = "turquoise", Z = "darkblue"), guide = "none") +
    facet_wrap(~ ID, nrow = 1, scales = "free_x") +
    theme_minimal() +
    theme(panel.grid = element_blank(),
          axis.text.x = element_blank(),
          axis.text.y = element_blank())
}

generate_random_colors <- function(n) {
  colors <- rgb(runif(n), runif(n), runif(n))
  return(colors)
}

plotActivityByID <- function(data, frequency) {
  my_colours <- generate_random_colors(length(unique(data$ID)))
  # summarise into a table
  labelledDataSummary <- data %>%
    #filter(!Activity %in% ignore_behaviours) %>%
    count(ID, Activity) %>%
    filter(!Activity == "")
  
  # account for the HZ, convert to minutes
  labelledDataSummaryplot <- labelledDataSummary %>%
    mutate(minutes = (n/frequency)/60)
  
  # Plot the stacked bar graph
  plot_activity_by_ID <- ggplot(labelledDataSummaryplot, aes(x = Activity, y = minutes, fill = as.factor(ID))) +
    geom_bar(stat = "identity") +
    labs(x = "Activity",
         y = "minutes") +
    theme_minimal() +
    scale_fill_manual(values = my_colours) +
    theme(axis.line = element_blank(),
          axis.text.x = element_text(angle = 45, hjust = 1),
          panel.border = element_rect(color = "black", fill = NA),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank())
  
  return(list(plot = plot_activity_by_ID,
              stats = labelledDataSummaryplot))
}

plotBehaviourDuration <- function(data, sample_rate){
  
  summary <- data %>%
    arrange(ID) %>%             # Sort by ID (not time because multiple trials in dog data)
    group_by(ID) %>%      
    mutate(
      behavior_change = lag(Activity) != Activity,  # Detect changes in Activity
      behavior_change = ifelse(is.na(behavior_change), TRUE, behavior_change)  # Handle the first row
    ) %>%
    mutate(
      behavior_id = cumsum(behavior_change)  # Create an identifier for each continuous behavior segment
    ) %>%
    group_by(ID, behavior_id) %>%            # Group by ID and behavior_id
    mutate(
      row_count = row_number()                # Count rows within each behavior segment
    ) %>%
    ungroup() %>%
    select(ID, Time, Activity, row_count, behavior_id) %>%   # Select relevant columns
    group_by(ID, Activity, behavior_id) %>%
    summarise(duration_sec = max(row_count)/100)
  
  duration_stats <- summary %>%
    group_by(Activity) %>%
    summarise(
      median = median(duration_sec, na.rm = TRUE),
      maximum = max(duration_sec, na.rm = TRUE),
      minimum = min(duration_sec, na.rm = TRUE)
    )
  
  # plot that
  duration_plot <- ggplot(summary, aes(x = Activity, y = as.numeric(duration_sec))) +
    geom_boxplot(aes(color = Activity)) +  # Use color to distinguish activities
    theme_minimal() +
    theme(
      legend.position = "none",             # Remove legend
      axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),  # Rotate x-axis labels 90 degrees
      panel.grid = element_blank(),         # Remove grid lines
      panel.border = element_rect(color = "black", fill = NA)  # Add black border around the plot
    ) +
    labs(
      x = "Activity",
      y = "Duration (seconds)"
    ) +
    scale_y_continuous(
      limits = c(min(summary$duration_sec, na.rm = TRUE), max(summary$duration_sec, na.rm = TRUE)),  # Set y-axis limits
      breaks = seq(0, max(summary$duration_sec, na.rm = TRUE), by = 160)  # Adjust the step size as needed
    )
  
  return(list(duration_plot = duration_plot,
              duration_stats = duration_stats))
}


plotUMAPVisualisation <- function(numeric_features, labels, minimum_distance, num_neighbours, shape_metric, spread) {

  # Train UMAP model on the known data
  umap_model_2D <- umap::umap(numeric_features, 
                              n_neighbors = num_neighbours, 
                              min_dist = minimum_distance, 
                              metric = shape_metric,
                              spread = spread)
  
  # umap_model_3D <- umap::umap(numeric_features, 
  #                             n_neighbors = num_neighbours, 
  #                             min_dist = minimum_distance, 
  #                             metric = shape_metric, 
  #                             spread = spread,
  #                             n_components = 3)
  
  # Apply the trained UMAP model on training data
  umap_result_2D <- umap_model_2D$layout
  # umap_result_3D <- umap_model_3D$layout
  
  # Create dataframes for 2D and 3D embeddings, add labels back
  umap_df <- as.data.frame(umap_result_2D)
  colnames(umap_df) <- c("UMAP1", "UMAP2")
  umap_df$Activity <- labels # this could cause an error when wrong length
  umap_df <- as.data.table(umap_df)
  umap_df$Activity <- as.factor(umap_df$Activity)
  
  
  # umap_df_3 <- as.data.frame(umap_result_3D)
  # colnames(umap_df_3) <- c("UMAP1", "UMAP2", "UMAP3")
  # umap_df_3$Activity <- labels[1:nrow(umap_df_3), ]
  
  # Plot the clusters in 2D
  UMAP_2D_plot <- ggplot(umap_df, aes(x = UMAP1, y = UMAP2, colour = Activity)) +
    geom_point(alpha = 0.6) +
    theme_minimal() +
    labs(x = "Dimension 1", y = "Dimension 2", colour = "Activity") +
    theme(legend.position = "right") +
    annotate("text", x = Inf, y = -Inf, label = paste("n_neighbors:", num_neighbours, "\nmin_dist:", minimum_distance, "\nmetric:", shape_metric),
             hjust = 1.1, vjust = -0.5, size = 3, color = "black", fontface = "italic")+
    scale_color_discrete()
  
  # Plot in 3D
  # UMAP_3D_plot <- plotly::plot_ly(umap_df_3, x = ~UMAP1, y = ~UMAP2, z = ~UMAP3, 
  #                                 color = ~Activity, colors = "Set1", 
  #                                 type = "scatter3d", mode = "markers",
  #                                 marker = list(size = 3, opacity = 0.5)) %>% 
  #   plotly::layout(scene = list(xaxis = list(title = "UMAP1"), yaxis = list(title = "UMAP2"), zaxis = list(title = "UMAP3")))
  
  return(list(
    # UMAP_3D_plot = UMAP_3D_plot,
    UMAP_2D_plot = UMAP_2D_plot,
    UMAP_2D_model = umap_model_2D,
    # UMAP_3D_model = umap_model_3D,
    UMAP_2D_embeddings = umap_df #,
    # UMAP_3D_embeddings = umap_df_3
  ))
}



# looking at feature information
boxplotFeatureData <- function(feature_data, n_col){
  summary <- feature_data %>%
    group_by(Activity, ID) %>%
    summarise(across(where(is.numeric), 
                     list(max = ~max(.), min = ~min(.), mean = ~mean(.), var = ~var(.)),
                     .names = "{col}_{fn}"))
  
  
  my_colours <- c("#66c2a5", "#fc8d62", "#8da0cb", "#e78ac3", "#a6d854", "#e49e18", 
                  "#ffd92f", "#e5c494", "#b3b3b3", "#ff69b4", "#ba55d3", "#3fd7af")
  
  
  numeric_cols <- colnames(feature_data)[!colnames(feature_data) %in% c("Activity", "Time", "ID")]
  
  plots <- list()
  
  # Loop over each numeric column and create a plot
  for (col in numeric_cols) {
    p <- ggplot(summary, aes_string(x = "Activity", y = paste0(col, "_mean"), color = "as.factor(ID)")) +
      geom_point(position = position_jitterdodge(jitter.width = 0.2), size = 3) +
      geom_errorbar(aes_string(ymin = paste0(col, "_min"), ymax = paste0(col, "_max")),
                    position = position_jitterdodge(jitter.width = 0.2),
                    width = 0.4) +
      labs(title = paste(col)) +
      scale_color_manual(values = my_colours, name = "ID") +
      theme_minimal() +
      theme(legend.position = "none",
            axis.line = element_blank(),
            axis.title.x = element_blank(),
            axis.title.y = element_blank(),
            axis.text.y = element_blank(),  # Remove y-axis labels
            panel.border = element_rect(color = "black", fill = NA),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank(),
            text = element_text(size = 8))
    
    plots[[col]] <- p
  }
  
  # Combine all plots into a single image
  multiplot <- do.call(gridExtra::grid.arrange, c(plots, ncol = n_col))
  
  return(activityPlot = multiplot)
}


# similar to above but more detailed
pointplotFeatureData <- function(feature_data, n_col){
  
  my_colours <- c("#66c2a5", "#fc8d62", "#8da0cb", "#e78ac3", "#a6d854", "#e49e18", 
                  "#ffd92f", "#e5c494", "#7a42f4", "#ff69b4", "#ba55d3", "#3fd7af")
  
  numeric_cols <- colnames(feature_data)[!colnames(feature_data) %in% c("Activity", "ID", "Time")]
  selected_cols <- grep("X", numeric_cols, value = TRUE)
  #selected_cols <- grep("Accelerometer", selected_cols, value = TRUE)
  filtered_data <- feature_data[, .SD, .SDcols = c(selected_cols, "Activity", "ID")]
  
  plots <- list()
  
  # Loop over each numeric column and create a plot
  for (col in selected_cols) {
    p <- ggplot(filtered_data, aes_string(x = "Activity", y = paste0(col), color = "as.factor(ID)")) +
      geom_point(position = position_jitterdodge(jitter.width = 0.1), size = 3, alpha = 0.5) +
      labs(title = paste(col)) +
      scale_color_manual(values = my_colours, name = "ID") +
      theme_minimal() +
      theme(legend.position = "none",
            axis.line = element_blank(),
            axis.title.x = element_blank(),
            axis.title.y = element_blank(),
            axis.text.y = element_blank(),
            panel.border = element_rect(color = "black", fill = NA),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank(),
            text = element_text(size = 8))
    
    plots[[col]] <- p
  }
  
  # Create a separate plot for the legend
  legend_plot <- ggplot(reduced_data, aes(x = "Activity", fill = as.factor(ID))) + 
    geom_bar() +
    scale_fill_manual(values = my_colours, name = "ID")
  leg <- get_legend(legend_plot)
  leg <- as_ggplot(leg)
  
  # Combine all plots into a single image
  multiplot <- do.call(gridExtra::grid.arrange, c(plots[selected_cols], ncol = n_col))
  multiplot_legend <- cowplot::plot_grid(multiplot, leg, ncol = 2, rel_widths = c(1, 0.2))
  
  return(multiplot_legend)
}

frequencyplotFeatureData <- function(feature_data, n_col){

  my_colours <- c("#66c2a5", "#d2691e", "#8da0cb", "#ff6f91", "#77dd77", "#ffb347", 
                  "#ffcc33", "#deb887", "#6b5b95", "#ff007f", "#9370db", "#ff6347")
  
  
  numeric_data <- feature_data %>% select(-c("Activity", "Time", "ID")) %>% scale()
  #selected_cols <- grep("X", colnames(numeric_data), value = TRUE)
  selected_cols <- colnames(numeric_data)
  scaled_data <- feature_data %>%
    select(Activity, ID) %>%
    bind_cols(numeric_data)
  
  plots <- list()
  
  # Loop over each numeric column and create a plot
  for (col in selected_cols) {
    #col <- selected_cols[1]
    p <- ggplot(scaled_data, aes_string(x = paste0(col), color = "as.factor(Activity)")) +
      geom_freqpoly(aes(y = ..density..), binwidth = 1, linewidth = 1) +
      labs(title = paste(col)) +
      scale_color_manual(values = my_colours, name = "ID") +
      theme_minimal() +
      theme(legend.position = "none",
            axis.line = element_blank(),
            axis.title.x = element_blank(),
            axis.title.y = element_blank(),
            axis.text.y = element_blank(),
            panel.border = element_rect(color = "black", fill = NA),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank(),
            text = element_text(size = 5))
    
    plots[[col]] <- p
  }
  
  # Create a separate plot for the legend
  legend_plot <- ggplot(feature_data, aes(x = "Activity", fill = as.factor(Activity))) + 
    geom_bar() +
    scale_fill_manual(values = my_colours, name = "ID")
  leg <- get_legend(legend_plot)
  leg <- as_ggplot(leg)
  
  # Combine all plots into a single image
  multiplot <- do.call(gridExtra::grid.arrange, c(plots[selected_cols], ncol = n_col))
  multiplot_frequency <- cowplot::plot_grid(multiplot, leg, ncol = 2, rel_widths = c(1, 0.1))
  
  return(multiplot_frequency)
}













# 
# 
# # Load in and set up ------------------------------------------------------
# raw_data <- fread(file.path(base_path, "Data", "RawOtherData.csv"))
# feature_data <- fread(file.path(base_path, "Data", "FeatureOtherData.csv"))
# 
# # Volume of data per class / individual -----------------------------------
# behaviours <- unique(data$GeneralisedActivity)
# individuals <- length(unique(data$ID))
# n_samples <- 200
# n_col <- 4
# 
# pdf(file = file.path(base_path, "Plots", "ActivityVolumeByID.pdf"),
# width = 16, # The width of the plot in inches
# height = 8)
# ActivityByID <- plotActivityByID(raw_data, frequency = sample_rate)
# ActivityByID$plot
# dev.off()
# 
# # Examples of trace -------------------------------------------------------
# pdf(file = file.path(base_path, "Plots", "TraceExamples.pdf"),
#     width = 16, # The width of the plot in inches
#     height = 8)
# plotTraceExamples(behaviours, raw_data, individuals, n_samples, n_col = n_col)
# dev.off()
# 
# # Duration of each behavioural bout ---------------------------------------
# pdf(file = file.path(base_path, "Plots", "BehaviourDuration.pdf"),
#     width = 16, # The width of the plot in inches
#     height = 8)
# BehaviourDuration <- plotBehaviourDuration(raw_data, sample_rate)
# BehaviourDuration$duration_plot
# dev.off()
# 
# 
# # Basic Feature Filtering -------------------------------------------------
# # remove obsolete and uninformative features
# 
# filtered_feature_columns <- removeBadFeatures(feature_data, threshold = 0.95)
# filtered_feature_data <-feature_data[, .SD, .SDcols = c(filtered_feature_columns, "Time", "ID", "Activity")]
# filtered_feature_data <- filtered_feature_data %>% na.omit()
# 
# # UMAP --------------------------------------------------------------------
# minimum_distance = 0.1
# num_neighbours = 10
# shape_metric = 'cosine'
# spread = 1
# 
# numeric_features <- filtered_feature_data %>% 
#   select(-c("Time", "ID", "Activity")) %>% 
#   mutate(across(everything(), as.numeric))
# labels <- feature_data %>% select("Activity")
# 
# pdf(file = file.path(base_path, "Plots", "UMAPExample1.pdf"),
#     width = 16, # The width of the plot in inches
#     height = 8)
# UMAPVisualisations <- plotUMAPVisualisation(numeric_features, labels, minimum_distance, num_neighbours, shape_metric, spread)
# UMAPVisualisations$UMAP_2D_plot
# dev.off()
# 
# # Explore feature space ---------------------------------------------------
# pdf(file = file.path(base_path, "Plots", "BoxplotFeatureAverages.pdf"),
#     width = 32, # The width of the plot in inches
#     height = 16)
# boxplotFeatureData(feature_data = filtered_feature_data, n_col = 4)
# dev.off()
# 
# pdf(file = file.path(base_path, "Plots", "FrequencyFeatureDistribution.pdf"),
#     width = 16, # The width of the plot in inches
#     height = 8)
# frequencyplotFeatureData(feature_data = filtered_feature_data, n_col = 5)
# dev.off()
# 
# # Unsupervised SOM Clustering ---------------------------------------------
# 
# 
# 
