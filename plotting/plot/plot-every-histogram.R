#!/usr/bin/env -S Rscript --no-save --no-restore

source("lib.R")
source("util.R")

# DUCKDB.FILE <<- "input/threadpool-every-0.1.duckdb"
# OUTPUT.DIR <<- "output"
read.input.args()
create.con()

SHORT.NAMES <<- TRUE

data <- dbGetQuery(con, 
  "SELECT finished.duration_ms,
      run.*
    FROM wf_log_finished finished 
      LEFT JOIN run USING(run_id);")

data <- factor.experiment(data)

for (commit in unique(data$experiment_commit_hash)) {
  print(commit)
  for (db_threadpool_size in unique(data$db_threadpool_size)) {
  print(db_threadpool_size)
  data.plot <- data[data$experiment_commit_hash == commit & data$db_threadpool_size == db_threadpool_size, ]

  plot <- ggplot() +
    ylab("Frequency") +
    xlab("Synchronization Time [ms]") +
    scale_y_log10() +
    facet_grid(
      patch_global_quiescence~benchmark_name,
      scales = "free_y",
      #independent="y"
    ) 
  plot <- plot + 
    geom_histogram(data = data.plot,
                   aes(x=duration_ms),
                   binwidth=1)
  
  
  plot <- plot + plot.theme.paper() +
    theme(legend.title = element_blank()) +
    theme(legend.position="top",
          legend.direction = "horizontal", 
          legend.justification="center",
          legend.box.just = "bottom",
          
          legend.margin=margin(0,0,0,0),
          #legend.spacing = unit(0, "pt"),
          legend.spacing.x = unit(0.3, 'line'),
          legend.box.spacing = unit(3, "pt"),
          #legend.box.margin = margin(0, 0, 0, 0),
          #legend.margin = margin(0)),
          legend.key.size = unit(0.5,"line"),
          #legend.key.width = unit(0.2, "line"),
    )
  
  
  ggplot.save(plot, paste("Synchronization-Time-Histogram", commit,db_threadpool_size, sep="-"), width=7.5, height = 3.2, use.grid=FALSE)
  }
}
