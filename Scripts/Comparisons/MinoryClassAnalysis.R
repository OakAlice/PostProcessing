## Precision and Recall
# We already know that the overall average F1-score for the dataset improves with postprocessing
# But what about the recall and precision?
# Specifically, what is happening to the rare classes?

# set up --------------------------------------------------------------------
pacman::p_load(tidyverse,
               data.table,
               patchwork,
               emmeans,
               glmmTMB)
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

prev_colours <- c("coral", "khaki2", "powderblue")
names(prev_colours) <- c("Minority", "Balanced", "Majority")



# Creating the data -------------------------------------------------------
# this bit of the code is just for me creating the data
# df <- fread(file.path("collated_performance.csv"))
# counts <- fread(file.path("Class_counts.csv"))
# 
# # prep the data
# baseline <- df %>%
#   filter(smoothing_type == "No") %>%
#   select(Species, Metric, rep_id, Activity, baseline = Score)
# data <- df %>%
#   left_join(baseline, by = c("Species", "rep_id", "Metric", "Activity")) %>%
#   mutate(relative_change = Score - baseline,
#          sp_rep = str_c(Species, "_", rep_id),
#          smoothing_type = factor(smoothing_type, levels = c("No", "Mode", "Duration", "Transition", "HMM", "Bayesian")), 
#          across(where(is.character), as.factor)) %>%
#   left_join(counts, by = c("Species", "Activity"))

# the data I attached to the email
data <- fread(file = file.path(base_path, "Output", "AllDataWithPrevalance.csv"))

data$smoothing_type <- factor(data$smoothing_type, levels = c("No", "Mode", "Duration", "Transition", "HMM", "Bayesian")) #, "LSTM"))
data$Species <- factor(data$Species, levels = c(unique(data$Species)))

# Create prevalence bins
# within each dataset, which of the behaviours are rare and which are common
# Desantis daatset only has 2 classes but others have 3 or more.

# total count for the dataset
total_counts <- data %>%
  distinct(Species, Activity, n) %>%
  group_by(Species) %>%
  summarise(total_n = sum(n), .groups = "drop")

prevalnce <- data %>%
  distinct(Species, Activity, n) %>%
  left_join(total_counts, by = "Species") %>%
  group_by(Species) %>%
  mutate(
    Equal_prev = 1 / n_distinct(Activity),
    Prevenace_prop = n / total_n,
    prevalence_class = case_when(
      Prevenace_prop < Equal_prev ~ "Minority",
      Prevenace_prop > 2 * Equal_prev ~ "Majority",
      TRUE ~ "Balanced"
    )
  )

data <-merge(data, prevalnce, by = c('Species', 'Activity'))

data <- data %>% dplyr::filter(smoothing_type != "No") %>%  
  mutate(smoothing_type = fct_drop(smoothing_type))

# Plot --------------------------------------------------------------------
## Precision ---------------------------------------------------------------
Prec <- data %>% dplyr::filter(Metric == "Precision")

Prec_bin_m <- glmmTMB(relative_change ~ smoothing_type * prevalence_class + (1|Species/rep_id), data = Prec)
emm <- emmeans(Prec_bin_m, ~ smoothing_type | prevalence_class)
emm_df <- as.data.frame(emm)
emm_df$prevalence_class <- factor(emm_df$prevalence_class, levels = c("Minority", "Balanced", "Majority"))
emm_df$smoothing_type <- factor(emm_df$smoothing_type, levels = c("No", "Mode", "Duration", "Transition", "HMM", "Bayesian")) #, "LSTM"))

prec_effect_plot <- ggplot(emm_df, 
                          aes(x = smoothing_type, y = emmean,
                              colour = prevalence_class)) +
  geom_point(size = 5, position = position_dodge(width = 0.7)) +
  geom_errorbar(aes(ymin = asymp.LCL, ymax = asymp.UCL), 
                width = 0.5, linewidth = 1, position = position_dodge(width = 0.7)) +
  geom_hline(yintercept = 0,
             linetype = "dashed",
             colour = "red") +
  my_theme() +
  scale_colour_manual(values = prev_colours) +
  labs(x = "Smoothing Type", y = "Change in Precision", colour = "Prevalence Class")

## Recall ---------------------------------------------------------------
Rec <- data %>% dplyr::filter(Metric == "Recall")
Rec_bin_m <- glmmTMB(relative_change ~ smoothing_type * prevalence_class + (1|Species/rep_id), data = Rec)
emm <- emmeans(Rec_bin_m, ~ smoothing_type | prevalence_class)
emm_df <- as.data.frame(emm)
emm_df$prevalence_class <- factor(emm_df$prevalence_class, levels = c("Minority", "Balanced", "Majority"))
emm_df$smoothing_type <- factor(emm_df$smoothing_type, levels = c("No", "Mode", "Duration", "Transition", "HMM", "Bayesian")) #, "LSTM"))

rec_effect_plot <- ggplot(emm_df, 
                         aes(x = smoothing_type, y = emmean,
                             colour = prevalence_class)) +
  geom_point(size = 5, position = position_dodge(width = 0.7)) +
  geom_errorbar(aes(ymin = asymp.LCL, ymax = asymp.UCL), 
                width = 0.5, linewidth = 1, position = position_dodge(width = 0.7)) +
  geom_hline(yintercept = 0,
             linetype = "dashed",
             colour = "red") +
  my_theme() +
  scale_colour_manual(values = prev_colours) +
  labs(x = "Smoothing Type", y = "Change in Recall", colour = "Prevalence Class")

## Together ----------------------------------------------------------------
figure <- ((prec_effect_plot + rec_effect_plot)  + plot_layout(guides = "collect")) &
  theme(
    legend.position = "bottom",
    legend.box = "horizontal",
    legend.title = element_text(size = 15),
    legend.text  = element_text(size = 15),
    legend.key.size = unit(0.4, "lines"),
    legend.spacing.x = unit(0.3, "cm"),
    legend.spacing.y = unit(0.2, "cm")
  )
figure


# Stats -------------------------------------------------------------------
# Hypothesis: The effect of post-processing will the same for each of the prevelance classes

# Precision
Prec <- data %>% dplyr::filter(Metric == "Precision")
Prec_bin_m <- glmmTMB(relative_change ~ smoothing_type * prevalence_class + (1|Species/rep_id), data = Prec)
car::Anova(Prec_bin_m, type = 3) # test the interaction
emm <- emmeans(Prec_bin_m, ~ smoothing_type | prevalence_class)
test(emm, null = 0)


# Recall
rec <- data %>% dplyr::filter(Metric == "Recall")
rec_bin_m <- glmmTMB(relative_change ~ smoothing_type * prevalence_class + (1|Species/rep_id), data = rec)
car::Anova(rec_bin_m, type = 3)
emm <- emmeans(rec_bin_m, ~ smoothing_type | prevalence_class)
test(emm, null = 0)

