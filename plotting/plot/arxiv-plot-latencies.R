#!/usr/bin/env -S Rscript --no-save --no-restore

# Used for latency charts

source("lib.R")
source("util.R")

#SHORT.NAMES <<- TRUE

# DUCKDB.FILE <<- "input/threadpool.duckdb"
# OUTPUT.DIR <<- "output"
read.input.args()
create.con()

lower_time_window_s <- 1.5
upper_time_window_s <- 1.5
plot.latency.time.cutout <- function(con,
                                     extreme_upper_quantile = 0.9995,
                                     sample_standard_rate = 0.1) {
  query <- sqlInterpolate(
    con,
    "
  WITH quantiles AS (
    SELECT run_id,
      QUANTILE_CONT(latency_us, ?extreme_upper_quantile) as extreme_quantile
    FROM latencies
    GROUP BY ALL
  ), min_quantiles AS (
    SELECT run_id,
      MIN(extreme_quantile) min_extreme_quantile
    FROM quantiles
    GROUP BY ALL
  ), extreme_latencies AS (
    SELECT run_id,
      latency_us,
      time_s
    FROM latencies LEFT JOIN quantiles USING(run_id)
    WHERE latencies.latency_us >= quantiles.extreme_quantile
  ), standard_sample_latencies AS (
    SELECT run_id,
      latency_us,
      time_s
    FROM latencies LEFT JOIN min_quantiles USING(run_id)
    WHERE latencies.latency_us < min_quantiles.min_extreme_quantile
    USING SAMPLE ?sample_standard_rate PERCENT (bernoulli)
  )
  SELECT * FROM (
    SELECT 'Extreme Latency' AS name,
      run.*,
      latency_us,
      time_s,
      benchmark_log_patch_time_s
    FROM extreme_latencies LEFT JOIN run USING(run_id) LEFT JOIN benchmark USING(run_id)
    UNION ALL
    SELECT 'Standard Latency' AS name,
      run.*,
      latency_us,
      time_s,
      benchmark_log_patch_time_s
    FROM standard_sample_latencies LEFT JOIN run USING(run_id) LEFT JOIN benchmark USING(run_id)
  )
  WHERE patch_time_s IS NULL
      OR (
        time_s <= (patch_time_s + ?upper_time_window_s)
        AND time_s >= (patch_time_s - ?lower_time_window_s)
      )
  ",
    extreme_upper_quantile = extreme_upper_quantile,
    sample_standard_rate = sample_standard_rate,
    lower_time_window_s = lower_time_window_s,
    upper_time_window_s = upper_time_window_s
  )
  data <- dbGetQuery(con, query)
  factor.experiment(data)
}
  
data <- plot.latency.time.cutout(con)
data$name <- factor(data$name)

# Get maximum latencies for each group
data_max_latency <- data %>% 
  group_by(benchmark_name, patch_global_quiescence, experiment_commit, patch_time_s) %>% 
  mutate(max_latency_us = max(latency_us)) %>%
  ungroup() %>%
  filter(latency_us==max_latency_us)

data.migration <- dbGetQuery(
  con,
  "
  SELECT duration_ms, benchmark.benchmark_log_patch_time_s, run.* FROM wf_log_finished LEFT JOIN run USING(run_id) LEFT JOIN benchmark USING(run_id) WHERE patch_global_quiescence = TRUE
  UNION ALL
  SELECT MAX(wf_log_migrated.duration_ms - wf_log_reach_quiescence.duration_ms), benchmark.benchmark_log_patch_time_s, run.* FROM wf_log_reach_quiescence LEFT JOIN wf_log_migrated USING(run_id) LEFT JOIN run USING(run_id) LEFT JOIN benchmark USING(run_id) WHERE patch_global_quiescence = FALSE GROUP BY ALL")
data.migration <- factor.experiment(data.migration)



ylim_expansion <- c(0, 0)
ylimglobalnoop <- mapply("-", range(data$latency_us[data$patch_global_quiescence == "Global Q" & data$benchmark_name == 'NoOp'] / 10**3), ylim_expansion)
ylimglobalycsb <- mapply("-", range(data$latency_us[data$patch_global_quiescence == "Global Q" & data$benchmark_name == 'YCSB']/ 10**3), ylim_expansion)
ylimglobaltpcc <- mapply("-", range(data$latency_us[data$patch_global_quiescence == "Global Q" & data$benchmark_name == 'TPC-C']/ 10**3), ylim_expansion)
ylimlocalnoop <- mapply("-", range(data$latency_us[data$patch_global_quiescence == "Local Q" & data$benchmark_name == 'NoOp']/ 10**3), ylim_expansion)
ylimlocalycsb <- mapply("-", range(data$latency_us[data$patch_global_quiescence == "Local Q" & data$benchmark_name == 'YCSB']/ 10**3), ylim_expansion)
ylimlocaltpcc <- mapply("-", range(data$latency_us[data$patch_global_quiescence == "Local Q" & data$benchmark_name == 'TPC-C']/ 10**3), ylim_expansion)
ylimbasenoop <- mapply("-", range(data$latency_us[data$patch_global_quiescence == "Baseline" & data$benchmark_name == 'NoOp']/ 10**3), ylim_expansion)
ylimbaseycsb <- mapply("-", range(data$latency_us[data$patch_global_quiescence == "Baseline" & data$benchmark_name == 'YCSB']/ 10**3), ylim_expansion)
ylimbasetpcc <- mapply("-", range(data$latency_us[data$patch_global_quiescence == "Baseline" & data$benchmark_name == 'TPC-C']/ 10**3), ylim_expansion)


# Style
plot <- ggplot() +
  ylab("Latency [ms]") +
  xlab("Elapsed Time [s]") +
  scale_x_continuous(breaks=c(5, 10, 15, 20, 25)) +
  facet_nested(
    benchmark_name + patch_global_quiescence ~ experiment_commit,
    scales = "free_y",
    independent = "y",
    strip = strip_nested(size = "variable")
  ) +
  facetted_pos_scales(
    y = list(
      patch_global_quiescence == "Baseline" & benchmark_name == "NoOp" & experiment_commit == "ID: 1" ~ scale_y_log10(limits = ylimbasenoop),
      patch_global_quiescence == "Baseline" & benchmark_name == "NoOp" & experiment_commit != "ID: 1" ~ scale_y_log10(limits = ylimbasenoop, guide = "none"),
      
      patch_global_quiescence == "Baseline" & benchmark_name == "YCSB" & experiment_commit == "ID: 1" ~ scale_y_log10(limits = ylimbaseycsb),
      patch_global_quiescence == "Baseline" & benchmark_name == "YCSB" & experiment_commit != "ID: 1" ~ scale_y_log10(limits = ylimbaseycsb, guide = "none"),
      
      patch_global_quiescence == "Baseline" & benchmark_name == "TPC-C" & experiment_commit == "ID: 1" ~ scale_y_log10(limits = ylimbasetpcc),
      patch_global_quiescence == "Baseline" & benchmark_name == "TPC-C" & experiment_commit != "ID: 1" ~ scale_y_log10(limits = ylimbasetpcc, guide = "none"),    
      
      patch_global_quiescence == "Global Q" & benchmark_name == "NoOp" & experiment_commit == "ID: 1" ~ scale_y_log10(limits = ylimglobalnoop),
      patch_global_quiescence == "Global Q" & benchmark_name == "NoOp" & experiment_commit != "ID: 1" ~ scale_y_log10(limits = ylimglobalnoop, guide = "none"),
      
      patch_global_quiescence == "Global Q" & benchmark_name == "YCSB" & experiment_commit == "ID: 1" ~ scale_y_log10(limits = ylimglobalycsb),
      patch_global_quiescence == "Global Q" & benchmark_name == "YCSB" & experiment_commit != "ID: 1" ~ scale_y_log10(limits = ylimglobalycsb, guide = "none"),
      
      patch_global_quiescence == "Global Q" & benchmark_name == "TPC-C" & experiment_commit == "ID: 1" ~ scale_y_log10(limits = ylimglobaltpcc),
      patch_global_quiescence == "Global Q" & benchmark_name == "TPC-C" & experiment_commit != "ID: 1" ~ scale_y_log10(limits = ylimglobaltpcc, guide = "none"),
      
      patch_global_quiescence == "Local Q" & benchmark_name == "NoOp" & experiment_commit == "ID: 1" ~ scale_y_log10(limits = ylimlocalnoop),
      patch_global_quiescence == "Local Q" & benchmark_name == "NoOp" & experiment_commit != "ID: 1" ~ scale_y_log10(limits = ylimlocalnoop, guide = "none"),
      
      patch_global_quiescence == "Local Q" & benchmark_name == "YCSB" & experiment_commit == "ID: 1" ~ scale_y_log10(limits = ylimlocalycsb),
      patch_global_quiescence == "Local Q" & benchmark_name == "YCSB" & experiment_commit != "ID: 1" ~ scale_y_log10(limits = ylimlocalycsb, guide = "none"),
      
      patch_global_quiescence == "Local Q" & benchmark_name == "TPC-C" & experiment_commit == "ID: 1" ~ scale_y_log10(limits = ylimlocaltpcc),
      patch_global_quiescence == "Local Q" & benchmark_name == "TPC-C" & experiment_commit != "ID: 1" ~ scale_y_log10(limits = ylimlocaltpcc, guide = "none")
    )
  )

# Add latency points
plot <- plot +
  geom_point(data = data,
             aes(
               x = time_s,
               y = latency_us / 10 ** 3,
               color = name,
               size = name
             )) +
  scale_size_manual(values=c(1.0, 0.4)) +
  # Add whitespace to name, as the last char. gets cut off somehow..
  scale_color_manual(values = c("black", "#CC7722")) +
  guides(color = guide_legend(override.aes = list(size=0.6))) +
  new_scale_color()

# Add label to max. latencies
plot <- plot +
  geom_label_repel(
    data = data_max_latency,
    aes(
      x = time_s,
      y = max_latency_us / 10 ** 3,
      label = round(max_latency_us / 10 ** 3, 1)
    ),
    label.padding = unit(0.25, "mm"),
    alpha = 0.7,
    fill = "black",
    color = "white",
    #Do not show the border because the border is white for a white color
    label.size = NA,
    # Draw every segment
    min.segment.length = 0,
    segment.size = 0.3,
    segment.color = "black",
    segment.alpha = 0.7,
    size = 3,
    #max.overlaps = Inf,
    stat = "unique",
  ) 

# Patch line
plot <- plot +
  geom_vline(
    data = data,
    aes(xintercept = benchmark_log_patch_time_s),
    color = "black",
    linetype = "dashed",
    linewidth = 0.25
  )

plot <- plot +
  geom_segment(
    data = data.migration,
    aes(x = benchmark_log_patch_time_s - lower_time_window_s,
        xend = benchmark_log_patch_time_s + upper_time_window_s,
        y = duration_ms,
        yend = duration_ms),
    color = "purple",
    size = 0.35
  )

plot <- plot + plot.theme.paper()


ggplot.save(plot +
              theme(legend.position = c(0.5,1.032),
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
              guides(color = guide_legend(nrow = 1))
            , "arxiv-Latencies-Cutout", width=16, height=15, use.grid=FALSE)

