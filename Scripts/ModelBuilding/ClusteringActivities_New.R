
# Clustering Activities into functional groups ----------------------------

if (file.exists(file.path(base_path, "Data", "FeatureOtherData_Clusters.csv"))){
  print("already clustered")
} else {
  
  feature_data <- fread(file.path(base_path, "Data", "FeatureOtherData.csv"))
  
  feature_data <- reclustering_behaviours(feature_data)
  
  fwrite(feature_data, file.path(base_path, "Data", "FeatureOtherData_Clusters.csv"))
}

reclustering_behaviours <- function(feature_data){
  
  behaviour_mapping <- list(
    Walking = c("Walking", "Bound/Half-Bound"),
    Still = c("Sleeping/Resting", "Tree Sitting"),
    TreeMovement = c("Branch Walking", "Swinging/Hanging", "Tree Movement"),
    Climbing = c("Climbing Up", "Climbing Down", "Rapid Climbing"),
    Feeding = c("Foraging/Eating"),
    Grooming = c("Grooming", "Shake"),
    Bellowing =c("Bellowing")
  )
  
  behaviour_mapping2 <- list(
    Walking = c("Walking"),
    Still = c("Sleeping/Resting"),
    TreeMovement = c("Branch Walking", "Swinging/Hanging", "Tree Movement", "Climbing Up", "Climbing Down", "Rapid Climbing",  "Shake"),
    Feeding = c("Foraging/Eating"),
    Grooming = c("Grooming"),
    Sitting = c("Tree Sitting"),
    Bellowing =c("Bellowing"),
    LocomotionOther = c("Bound/Half-Bound")
  )
  
  behaviour_lookup <- unlist(lapply(names(behaviour_mapping), function(group) {
    setNames(rep(group, length(behaviour_mapping[[group]])), behaviour_mapping[[group]])
  }))
  
  behaviour_lookup2 <- unlist(lapply(names(behaviour_mapping2), function(group) {
    setNames(rep(group, length(behaviour_mapping2[[group]])), behaviour_mapping2[[group]])
  }))
  
  # assign and save
  feature_data$GeneralisedActivity <- behaviour_lookup[feature_data$Activity]
  feature_data$GeneralisedActivity2 <- behaviour_lookup2[feature_data$Activity]
  
  return(feature_data)
}
