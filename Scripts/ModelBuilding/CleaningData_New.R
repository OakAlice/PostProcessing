
# CleaningData ------------------------------------------------------------

# if already reclustered, load in, else do

  
  # group behaviours into generalised groups
  data[, GeneralisedActivity := fifelse( # exclude bellowing from model and cluster other activities
    Activity %in% c("Branch Walking", "Tree Movement", "Swinging/Hanging"), "TreeMovement",
    fifelse(Activity %in% c("Climbing up", "Rapid Climbing", "Climbing Down"), "Climbing",
            fifelse(Activity %in% c("Foraging/Eating"), "Feed",
                    fifelse(Activity == "Tree Sitting", "TreeSitting", 
                            fifelse(Activity == "Ground Sitting", "GroundSitting",
                                    fifelse(Activity %in% c("Sleeping/Resting"), "Still",
                                            fifelse(Activity %in% c("Shake", "Grooming"), "Groom", 
                                                    fifelse(Activity %in% c("Walking", "Bound/Half-Bound"), "Walking", "NA")
                                            )))))))]
  
  data <- data %>% filter(GeneralisedActivity != "NA") %>% na.omit()
  
  fwrite(data, file.path(base_path, "Data", "ClusteredTrainingData.csv"))
}

# Plot behaviour shapes and volume ------------------------------------------
behaviours <- unique(data$GeneralisedActivity)
individuals <- length(unique(data$ID))
n_samples <- 500
n_col <- 4

plotTraceExamples(behaviours, data, individuals, n_samples, n_col = n_col)
plotActivityByID(data, frequency = sample_rate, colours = individuals)

# plot each individualal behaviour full volume # if you want
# behaviourData <- data %>% filter(Activity == "Bound/Half-Bound") %>%
#   mutate(rowID = row_number())
# 
# ggplot(behaviourData, aes(x = rowID)) +
#   geom_line(aes(y = Accelerometer.X, color = "X"), show.legend = FALSE) +
#   geom_line(aes(y = Accelerometer.Y, color = "Y"), show.legend = FALSE) +
#   geom_line(aes(y = Accelerometer.Z, color = "Z"), show.legend = FALSE) +
#   labs(title = paste(behaviourData$Activity[1]),
#        x = NULL, y = NULL) +
#   scale_color_manual(values = c(X = "salmon", Y = "turquoise", Z = "darkblue"), guide = "none") +
#   facet_wrap(~ ID, nrow = 3, scales = "free_x") +
#   theme_minimal() +
#   theme(panel.grid = element_blank(),
#         axis.text.x = element_blank(),
#         axis.text.y = element_blank())


# Downsampling overrepresented behaviours ---------------------------------
max_minutes <- 20
max_samples <- sample_rate * 60 * max_minutes

if(file.exists(file.path(base_path, "Data", "BalancedClusteredTrainingData.csv"))){
  fread(file.path(base_path, "Data", "BalancedClusteredTrainingData.csv"))
} else {
  data <- fread(file.path(base_path, "Data", "ClusteredTrainingData.csv")) %>% 
    mutate(rowID = row_number()) %>% filter(Activity != "")
  
  # confusing, need to change this bit
  data$GeneralisedActivity <- data$GeneralisedActivity # change this so I'm downsampling the right thing
  
  downsampled_data <- data %>% group_by(ID, Activity) %>% arrange(rowID) %>%
    slice(1:max_samples) %>% 
    ungroup() %>% arrange(rowID)
  
  plotActivityByID(downsampled_data, frequency = sample_rate, colours = length(unique(downsampled_data$ID)))
  
  # when you're happy with that, save it
  fwrite(downsampled_data, file.path(base_path, "Data", "BalancedClusteredTrainingData.csv"))
}

