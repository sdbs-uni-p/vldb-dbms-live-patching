#!/usr/bin/env -S Rscript --no-save --no-restore

# This file parses the output from 'example-mmview2'
# It produces a plot for which each single latency is shown.
# In addition, the migration time and the time for creating a new AS is shown.
source("lib.R")
source("util.R")

read.input.args()
# DUCKDB.FILE <- "input/data"

get.delay.and.pte <- function(experiment, sleep_time) {
  dir <- paste(DUCKDB.FILE, "/result-", experiment, "-", sleep_time, sep="")
  print(paste("Loading", dir))
  
  if (!dir.exists(dir)) {
    next
  }
  
  latencies <- read.csv(paste(dir, "latencies.csv", sep="/"))
  latencies$experiment <- experiment
  latencies$time_s <- ((latencies$time - min(latencies$time)) / 1000.)
  
  print(paste("Max time:", max(latencies$time_s)))
  if (max(latencies$time_s) < sleep_time) {
    stop("Max. time is less than sleep time. This data has not captured the event!")
  }
  
  wf_latencies <- tryCatch(read.csv(paste(dir, "wfpatch_log.csv", sep="/")), error = function(e) NULL)
  if (is.null(wf_latencies)) {
    #stop("wfpatch_log.csv is empty!")
    return(data.frame())
  }
  wf_latencies$experiment <- experiment
  wf_latencies$latency_kernel_time[wf_latencies$latency_kernel_time <= 0] <- NA
  wf_latencies$latency_switch_time[wf_latencies$latency_switch_time <= 0] <- NA
  wf_latencies$latency_kernel_time_s <- ((wf_latencies$latency_kernel_time - min(latencies$time)) / 1000.)
  wf_latencies$latency_switch_time_s <- ((wf_latencies$latency_switch_time - min(latencies$time)) / 1000.)
  
  if (nrow(wf_latencies) != 1) {
    stop("We assume that wf_latencies has only one entry!")
  }
  
  latencies <- latencies[order(latencies$time_s), ]
  time_s_diff <- diff(latencies$time_s) 
  time_s_diff <- append(time_s_diff, NA)
  latencies$time_s_diff <- time_s_diff
  
  # We can use +-1 second, because time_s is the *start* of a query
  filter_time_upper <- wf_latencies$latency_kernel_time_s + 1
  filter_time_lower <- wf_latencies$latency_kernel_time_s - 1
  if (experiment == 0) {
    # Baseline
    filter_time_upper <- Inf
    filter_time_lower <- -Inf
  }
  max_latency_summary <- latencies %>% 
    filter(time_s < !!filter_time_upper) %>%
    filter(time_s > !!filter_time_lower) %>%
    group_by(thread_id) %>%
    summarise(min_max_time_diff = max(time_s_diff),
           max_latency = max(latency_ms)) %>%
    ungroup() %>%
    summarise(summary_latency = max(max_latency)  / 1000)
  return(data.frame(max_diff_time_s=max_latency_summary$summary_latency,
                    pte_size_kB=wf_latencies$pte_size_kB))
  
  #row_max_diff <- latencies[which.max(latencies$time_s_diff), ]
  
  #if (experiment == 0 || 
  #    (row_max_diff$time_s + 1 > wf_latencies$latency_kernel_time_s &&
  #    row_max_diff$time_s - 1 < wf_latencies$latency_kernel_time_s)) {
  #  return(data.frame(max_diff_time_s = row_max_diff$time_s_diff, 
  #                    pte_size_kB=wf_latencies$pte_size_kB))
  #} else {
  #  print(row_max_diff)
  #  print(wf_latencies)
  #  # Skip such entries...
  #  stop(paste("Please debug, no max. gap found in the range of action. Experiment:", experiment))
  #  #return(data.frame())
  #}
}

data <- data.frame()
# , 150, 175, 200, 225, 250, 275
for(sleep_time in 1:200) {
  # New AS
  as.data <- get.delay.and.pte(5, sleep_time)
  if (ncol(as.data) > 0) {
    as.data$experiment <- "New AS"
  }
  
  # Fork
  fork.data <- get.delay.and.pte(6, sleep_time)
  if (ncol(fork.data) > 0) {
    fork.data$experiment <- "Fork"
  }

  # Overall 
  nopatch.data <- get.delay.and.pte(0, sleep_time)
  if (ncol(nopatch.data) > 0) {
    nopatch.data$experiment <- "Baseline"
  }
  
  all.data <- rbindlist(list(as.data, fork.data, nopatch.data))
  if (ncol(all.data) > 0) {
    all.data$sleep_time <- sleep_time  
    data <- rbind(data, all.data)
  }
}

data$experiment <- factor(data$experiment)
data$sleep_time <- factor(data$sleep_time)

data$pte_size_mB <- data$pte_size_kB / 1000

# Style
plot <- ggplot() +
  ylab("Max.\nLatency\n[s]") +
  xlab("PTE Size [MB]") +
  scale_y_continuous()


plot <- plot +
  geom_point(data=data,
             aes(
               x = pte_size_mB,
               y = max_diff_time_s,
               color = experiment,
               shape = experiment
             ),
             size=0.18) +
  scale_color_manual( name="Method:", values=c("blue", "#007300", "#00e000")) +
  scale_shape_manual(name="Method:", values=c(16, 16, 16))

#plot <- plot +
#  geom_line(data=data,
#             aes(
#               x = pte_size_mB,
#               y = max_diff_time_s,
#               color = experiment,
#               linetype = experiment,
#               group = experiment
#             )) +
#  scale_color_manual(values=c("green", "orange", "black"), name="Method:") +
#  scale_linetype(name="Method:")

plot <- plot + plot.theme.paper() +
  theme(legend.position = c(0.5,1.15),
        plot.margin = margin(3, 0.5, 0.5, 0.5, unit="mm"),
        axis.title.y = element_text(margin = margin(r=3), hjust=0.6),
        legend.direction ="horizontal",
        legend.text = element_text(size = FONT.SIZE - 1, margin=margin(l=-3)),
        legend.key.size = unit(1, "mm"),
        legend.margin = margin(0,0,0,0),
        legend.title = element_blank(),
        legend.background = element_blank(),
        # Horizontal spacing between facets
        panel.spacing.x = unit(0.6, "mm"),
        panel.spacing.y = unit(1, "mm")
  ) + 
  guides(color = guide_legend(override.aes = list(size = 0.6)))
  


print("Saving plot...")
ggplot.save(plot, "AS-Fork-Line", width=7.5, height=1.8)

