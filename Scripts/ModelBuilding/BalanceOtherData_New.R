# Balancing the samples from over represented individuals -----------------

if (file.exists(file.path(base_path, "Data", "BalancedOtherData.csv"))){
  balanced_data_other <- fread(file.path(base_path, "Data", "BalancedOtherData.csv"))
} else {
  
  # play with this manually
  data1 <- fread(file.path(base_path, "Data", "RawOtherData.csv"))
  
  # visualise the data volumes
  ActivityByID <- plotActivityByID(data = data1, frequency = sample_rate)
  ActivityByID$plot
  
  # visualise particualr behaviours in their entirity to see if they are representitive
  subdata <- data1 %>% filter(ID == "Meeka")
  plot_behaviour(behaviour = "Tree Movement", n_samples = 10000, data = subdata)
  
  # how many windows would there be?
  windows <- length(data1$Time) / (sample_rate * window_length)
  
  
  # okay, maybe downsample it to a maximum of 50 minutes per behaviour total, split equally between individuals
  baalnced_data <- data1 %>% group_by(ID, Activity) %>% slice(1:75000)
  ActivityByID <- plotActivityByID(data = baalnced_data, frequency = sample_rate)
  ActivityByID$plot
  windows <- length(baalnced_data$Time) / (sample_rate * window_length)
  
  fwrite(baalnced_data, file.path(base_path, "Data", "BalancedOtherData.csv"))
}