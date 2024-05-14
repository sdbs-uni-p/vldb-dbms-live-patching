#!/usr/bin/env -S Rscript --no-save --no-restore

# Used for one-thread-per-connection CH-benCHmark

source("lib.R")
source("util.R")

read.input.args()
# DUCKDB.FILE <- "input/one-thread-per-connection-ch.duckdb"
# OUTPUT.DIR <- "output"
create.con()

TIME.DIVIDE <- 60
SHAPE.LATENCY <- 4
SHAPE.WARMUP <- 2
SHAPE.DONE <- 4

plot.latency.time <- function(con, 
                              custom.data.filter=NULL, 
                              custom.size.factor = 1.0, 
                              scale.y.label.step=NULL) {
  GAP.BETWEEN.WORKER <- 0.25 * (log(custom.size.factor) + 1)# 0.4, i.e. 0.4 is added/subtracted from the y position
  #data <- dbGetQuery(con, "SELECT * FROM latencies
  #                   LEFT JOIN run USING(run_id);")
  #data <- factor.experiment(data)
  
  data <- dbGetQuery(con, "
SELECT latencies.time_s, latencies.worker_id, latencies.latency_us, run.*
FROM latencies
LEFT JOIN run USING(run_id);
  ")
  data <- factor.experiment(data)
  
  data.warmup <- dbGetQuery(con, "
SELECT benchmark_log_warmup.time_s, benchmark_log_warmup.worker_id, benchmark_log_warmup.latency_us, run.*
FROM benchmark_log_warmup
LEFT JOIN run USING(run_id);
  ")
  data.warmup <- factor.experiment(data.warmup)
  
  data.done <- dbGetQuery(con, "
SELECT *
FROM benchmark_log_done
LEFT JOIN run USING(run_id);
  ")
  data.done <- factor.experiment(data.done)
  
  data.patch <- dbGetQuery(con, "
SELECT *
FROM run
LEFT JOIN (
	SELECT run_id, 
	  thread_id, 
	  (benchmark_log_patch_time_s + (wf_log_reach_quiescence.duration_ms/10**3)) as reach_quiescence_time_s,
	  (benchmark_log_patch_time_s + (wf_log_finished.duration_ms/10**3)) as migrated_time_s,
	  benchmark_log_duration_s,
	  benchmark_log_patch_time_s AS start_patch_time_s, 
		(benchmark_log_patch_time_s + (wf_log_finished.duration_ms/10**3)) AS end_patch_time_s
	FROM wf_log_reach_quiescence
	LEFT JOIN wf_log_finished USING(run_id)
	LEFT JOIN benchmark USING(run_id)
	LEFT JOIN run USING(run_id)
	WHERE run.patch_global_quiescence = TRUE
	AND thread_id >= 1 AND thread_id <= 10
	
	UNION ALL
	
	SELECT run_id, 
	  thread_id, 
	  (benchmark_log_patch_time_s + (wf_log_reach_quiescence.duration_ms/10**3)) as reach_quiescence_time_s,
	  (benchmark_log_patch_time_s + (wf_log_migrated.duration_ms/10**3)) as migrated_time_s,
	  benchmark_log_duration_s,
	  benchmark_log_patch_time_s AS start_patch_time_s, 
		(benchmark_log_patch_time_s + (wf_log_finished.duration_ms/10**3)) AS end_patch_time_s
	FROM wf_log_reach_quiescence
	LEFT JOIN wf_log_migrated USING(run_id, thread_id)
	LEFT JOIN wf_log_finished USING(run_id)
	LEFT JOIN benchmark USING(run_id)
	LEFT JOIN run USING(run_id)
	WHERE run.patch_global_quiescence = FALSE
	AND thread_id >= 1 AND thread_id <= 10
	
) USING(run_id)
;
  ")
  data.patch <- factor.experiment(data.patch)
  
  
  # First worker has ID 0. This is bad to display for the y axis
  data$worker_id <- data$worker_id + 1
  data.warmup$worker_id <- data.warmup$worker_id + 1
  data.done$worker_id <- data.done$worker_id + 1
  
  if (!is.null(custom.data.filter)) {
    data <- custom.data.filter(data)
    data.patch <- custom.data.filter(data.patch)
    data.warmup <- custom.data.filter(data.warmup)
    data.done <- custom.data.filter(data.done)
  }
  
  data <- rbind(data, data.warmup)
  data.warmup <- data.warmup[0, ] # Clear rows
  
  # Style
  scale.y.breaks = seq(min(data$worker_id), max(data$worker_id), by=1)
  scale.y.labels <- scale.y.breaks
  if (!is.null(scale.y.label.step)) {
    # Replace every second label with ""
    scale.y.labels[-seq(min(data$worker_id), max(data$worker_id), by=2)] <- ""
    print(scale.y.labels)
  }
  
  plot <- ggplot() +
    ylab("Worker ID") +
    xlab("Elapsed Time [m]") +
    scale_x_continuous(expand = c(0, 0), breaks=c(0, 5, 10, 15, 20, 25, 30)) +
    scale_y_continuous(expand = c(0.05, 0.05), breaks = scale.y.breaks, labels=scale.y.labels) + 
    coord_cartesian(xlim = c(-120 / TIME.DIVIDE, max(data.patch$benchmark_log_duration_s / TIME.DIVIDE, na.rm=TRUE) + 120 / TIME.DIVIDE)) + 
    facet_grid(
      patch_global_quiescence ~ experiment_commit
    )
  plot <- plot +
    geom_point(data = data,
               aes(
                 x = time_s / TIME.DIVIDE,
                 y = worker_id,
               ),
               shape = SHAPE.LATENCY,
               size = 1 * custom.size.factor,
               color = "black")
  
  # Add latency start points
  plot <- plot +
    geom_point(data = data,
               aes(
                 x = time_s / TIME.DIVIDE,
                 y = worker_id,
               ),
               shape = SHAPE.LATENCY,
               size = 1 * custom.size.factor,
               color = "black")
  # Add latency end points
  plot <- plot +
    geom_point(data = data,
               aes(
                 x = (time_s + (latency_us / 10**6)) / TIME.DIVIDE,
                 y = worker_id,
               ),
               shape = SHAPE.LATENCY,
               size = 1 * custom.size.factor,
               color = "black")
  # Line between points
  plot <- plot +
    geom_segment(
      data = data,
      aes(x = time_s / TIME.DIVIDE,
          xend = (time_s + (latency_us / 10**6)) / TIME.DIVIDE,
          y = worker_id,
          yend = worker_id),
      color = "black",
      na.rm = TRUE,
      size = 0.2 * custom.size.factor
    )
  
  # Add warmup start points
  #plot <- plot +
  #  geom_point(data = data.warmup,
  #             aes(
  #               x = time_s / TIME.DIVIDE,
  #               y = worker_id,
  #             ),
  #             shape = SHAPE.WARMUP,
  #             size = 1 * custom.size.factor,
  #             #alpha = 0.5,
  #             color = "purple")
  # Add warmup latency end points
#  plot <- plot +
#    geom_point(data = data.warmup,
#               aes(
#                 x = (time_s + (latency_us / 10**6)) / TIME.DIVIDE,
#                 y = worker_id - GAP.BETWEEN.WORKER,
#               ),
#               shape = 24,
#               alpha = 0.5,
#               color = "black")
  # Line between warmup points
  plot <- plot +
    geom_segment(
      data = data.warmup,
      aes(x = time_s / TIME.DIVIDE,
          xend = (time_s + (latency_us / 10**6)) / TIME.DIVIDE,
          y = worker_id,
          yend = worker_id),
      color = "purple",
      #alpha = 0.5,
      linetype="dotted",
      na.rm = TRUE,
      size = 0.2 * custom.size.factor
    )
  # Add done start points
  plot <- plot +
    geom_point(data = data.done,
               aes(
                 x = time_s / TIME.DIVIDE,
                 y = worker_id,
               ),
               shape = SHAPE.DONE,
               size = 0.5 * custom.size.factor,
               #alpha = 0.5,
               color = "purple")
  # Add done latency end points
  plot <- plot +
    geom_point(data = data.done,
                 aes(
                 x = (time_s + (latency_us / 10**6)) / TIME.DIVIDE,
                 y = worker_id,
               ),
               shape = SHAPE.DONE,
               size = 0.5 * custom.size.factor,
               #alpha = 0.5,
               color = "purple")
  # Line between done points
  plot <- plot +
    geom_segment(
      data = data.done,
      aes(x = time_s / TIME.DIVIDE,
          xend = (time_s + (latency_us / 10**6)) / TIME.DIVIDE,
          y = worker_id,
          yend = worker_id),
      color = "purple",
      #alpha = 0.5,
      linetype="dotted",
      na.rm = TRUE,
      size = 0.2 * custom.size.factor
    )
  
  # Reach Quiescence
  plot <- plot +
    geom_segment(data = data.patch,
                 aes(
                   x = reach_quiescence_time_s / TIME.DIVIDE,
                   xend = reach_quiescence_time_s / TIME.DIVIDE,
                   y = thread_id - GAP.BETWEEN.WORKER,
                   yend = thread_id + GAP.BETWEEN.WORKER
                 ),
                 linewidth = 0.3 * custom.size.factor,
                 color = "red")
  # Migrated to new version
  plot <- plot +
    geom_segment(data = data.patch,
                 aes(
                   x = migrated_time_s / TIME.DIVIDE,
                   xend = migrated_time_s / TIME.DIVIDE,
                   y = thread_id - GAP.BETWEEN.WORKER,
                   yend = thread_id + GAP.BETWEEN.WORKER
                 ),
                 linewidth = 0.3 * custom.size.factor,
                 color = "red")
  
  
  # Line - Thread blocked
  plot <- plot +
    geom_segment(
      data = data.patch,
      aes(x = reach_quiescence_time_s / TIME.DIVIDE,
          xend = migrated_time_s / TIME.DIVIDE,
          y = thread_id,
          yend = thread_id),
      color = "red",
      na.rm = TRUE,
      size = 0.2 * custom.size.factor
    )
  
  # Start Patch line
  #plot <- plot +
  #  geom_vline(
  #    data = data.patch,
  #    aes(xintercept = start_patch_time_s / TIME.DIVIDE),
  #    color = "black",
  #    linetype = "dashed",
  #    linewidth = 0.2
  #  )
  # End Patch line
  #plot <- plot +
  #  geom_vline(
  #    data = data.patch,
  #    aes(xintercept = end_patch_time_s / TIME.DIVIDE),
  #    color = "black",
  #    linetype = "dashed",
  #    linewidth = 0.2
  #  )
  
  # Patch rectangle
  plot <- plot +
    geom_rect(data = data.patch,
              aes(ymin=!!min(data$worker_id) - GAP.BETWEEN.WORKER, 
                  ymax=!!max(data$worker_id) + GAP.BETWEEN.WORKER,
                  xmin=start_patch_time_s / TIME.DIVIDE, 
                  xmax=end_patch_time_s / TIME.DIVIDE),
              fill="orange",
              stat = "unique",
              alpha=0.3)
  
  
  plot <- plot + plot.theme.paper() 
  plot +
    theme(
      plot.margin = margin(0.5, 0.5, 0.5, 0.5, unit="mm"),
      axis.title.y = element_text(margin = margin(r=3), hjust=0.5),
      # Horizontal spacing between facets
      panel.spacing.x = unit(0.6, "mm"),
      panel.spacing.y = unit(1, "mm")
    )
}


# filter.data.small <- function(df) {
#   df[df$experiment_commit %in% levels(df$experiment_commit)[2:length(levels(df$experiment_commit))], ]
# }
# 
# filter.data.big <- function(df) {
#   df[df$experiment_commit == levels(df$experiment_commit)[[1]] & df$patch_global_quiescence != "-", ]
# }
# 
# 
# latency.time.small <- plot.latency.time(con, custom.data.filter=filter.data.small, scale.y.label.step = 2) +
#   scale_x_continuous(expand = c(0, 0), breaks=c(0, 5, 10, 15, 20, 25, 30), labels=c("", "5", "", "15", "", "25", "")) +
#   theme(axis.title = element_blank())
# latency.time.big <- plot.latency.time(con,
#                                       custom.data.filter=filter.data.big,
#                                       custom.size.factor=1+2/3) +
#   theme(axis.title.x = element_blank(),
#       axis.title.y = element_text(margin = margin(t=0, r=5, b=0, l=0)))
# 
# latency.time <- plot_grid(latency.time.big, latency.time.small, rel_widths = c(1, 2)) +
#   theme(plot.margin=margin(0, 0, 10, 0)) +
#   draw_label("Time [m]", x=0.5, y=0, vjust=0.5, angle= 0,
#              fontfamily = "paper", fontface = "bold", size = FONT.SIZE)
#   #draw_label("Worker ID", x=  0, y=0.5, vjust= 1.5, angle=90)


filter.data <- function(df) {
  df[df$experiment_commit %in% levels(df$experiment_commit)[1:2], ]  
}

latency.time <- plot.latency.time(con, custom.data.filter=filter.data)
ggplot.save(latency.time, "CH-Latency-per-Worker", width=7.5, height = 6.5, use.grid=FALSE)

latency.time.full <- plot.latency.time(con, custom.data.filter=NULL)
ggplot.save(latency.time.full, "CH-Latency-per-Worker-All-Patches", width=18, height = 7, use.grid=FALSE)
