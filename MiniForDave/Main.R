# Miniture version of the analysis for Dave to check ----------------------

# Set up ------------------------------------------------------------------
pacman::p_load(tidyverse,
               data.table,
               glmmTMB,
               MuMIn
               )

base_path <- "C:/Users/oaw001/OneDrive - University of the Sunshine Coast/PostProcessing"

# helper functions # using your system lol # these are just plot functions
helpers <- source(file.path(base_path, "MiniForDave", "helpers.R")) 

# prepping the data (calculating relative change)
data <- fread(file.path(base_path, "MiniForDave", "collated_performance.csv")) # performance
stat_file <- fread(file.path(base_path, "MiniForDave", "All_sequence_stats.csv")) # stats about the training data
full_df <- merge(data, stat_file, by = "Species")

df <- full_df %>% filter(Activity == "Macro-Average", Metric == "F1")
baseline <- df %>%
  filter(smoothing_type == "No") %>%
  select(Species, rep_id, baseline = Score)
df <- df %>%
  left_join(baseline, by = c("Species", "rep_id")) %>%
  mutate(relative_change = Score - baseline) 

df$smoothing_type <- factor(df$smoothing_type, levels = c("No", "Mode", "Duration", "Transition", "HMM", "Bayesian"))

# Q1: Overall performance -------------------------------------------------
# Overall performance of the post-processors irrespective of species
# Null hypothesis: Macro-average F1 of each of the methods will not be better than control ('No')

m1 <- glmmTMB(relative_change ~ smoothing_type + (1|Species/rep_id), data = df)
summary(m1)

# and a plot of that same question
# Summarise mean and 95% CI
summary_df <- df %>%
  group_by(Species, smoothing_type) %>%
  summarise(
    n = n(),
    mean_rel = mean(relative_change, na.rm = TRUE),
    se = sd(relative_change, na.rm = TRUE) / sqrt(n),
    ci = 1.96 * se, # gives us the confidence intervals (I think??)
    .groups = "drop"
  )

ggplot(summary_df %>% dplyr::filter(!smoothing_type == "No"),# this is 0 every time, so replace with a flat line for visually cleaner
       aes(x = smoothing_type,
           y = mean_rel,
           colour = smoothing_type)) +
  geom_point(size = 3) +
  geom_errorbar(aes(ymin = mean_rel - ci,
                    ymax = mean_rel + ci),
                width = 0.5) +
  geom_hline(yintercept = 0, linetype = "dotted", colour = "black") +
  my_theme() +
  scale_colour_manual(values = my_colours) +
  labs(x = "Smoothing Type",
       y = "Mean change in F1 (relative to No smoothing)",
       fill = "Smoothing Type") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "none") +
  facet_wrap(~Species, ncol = 3)


# Q2: Performance within each species dataset -----------------------------
# Accounting for interaction of species
# Null hypothesis: There will be no interaction between species and smoothing type

m2 <- glmmTMB(relative_change ~ smoothing_type * Species + (1|rep_id), data = df)
summary(m2)

# since there are some interactions, we should look at the datasets separately
# Null hypothesis: Within each species (assessed independently), the macro-average F1 of each of the methods will not be better than control ('No')
species <- unique(df$Species)
all_stats <- data.frame()
for (x in species){
  dat <- df %>% filter(Species == x)
  mod <- glmmTMB(
    relative_change ~ smoothing_type + (1 | rep_id),
    data = dat
  )

  stats <- as.data.frame(summary(mod)$coefficients$cond)
  stats$Species <- x
  stats$sig <- ifelse(stats$`Pr(>|z|)` < 0.05, TRUE, FALSE)
  stats$smoothing_type <- gsub("smoothing_type", "", rownames(stats))
  
  all_stats <- rbind(all_stats, stats)
}

# just inspecting the ones that were significant
sig_stats <- all_stats %>% filter(sig == TRUE)
sig_stats


# Q3: Effect of training data structure on effect of postprocessing -------
# Can we predict the datasets in which postprocessing will incur advantage by traits
# of the training data
# Null hypothesis: None of the transition variables are able to predict the better performance

# note that the covariables are pretty unique to the species so Species is colinear with them (???)
# therefore I left Species as a random effect

# scale everything so one variable doesnt have much bigger effect
df <- df %>%
  mutate(across(
    c(mean_transitions, total_transitions, Num_Activities),
    ~ scale(.x, center = TRUE, scale = TRUE)[,1]
  ))

null_m <- glmmTMB(relative_change ~ smoothing_type + (1|Species/rep_id), data = df)

m3 <- glmmTMB(relative_change ~ smoothing_type + 
                    mean_transitions + multi_behaviour + Num_Activities +
                    (1|Species/rep_id), data = df)

anova(null_m, m3)
r.squaredGLMM(m3)

summary(m3)


# but maybe I should be looking at the interactions between those variables
m4 <- glmmTMB(relative_change ~ smoothing_type * 
                (mean_transitions + multi_behaviour + Num_Activities) +
                (1|Species/rep_id), data = df)
anova(m3, m4)
summary(m4)
