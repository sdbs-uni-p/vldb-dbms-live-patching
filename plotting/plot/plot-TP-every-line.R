#!/usr/bin/env -S Rscript --no-save --no-restore

source("lib.R")
source("util.R")

# DUCKDB.FILE <<- "input/threadpool-every-0.1.duckdb"
# OUTPUT.DIR <<- "output"
read.input.args()
create.con()

SHORT.NAMES <<- TRUE

data <- dbGetQuery(con, 
  "SELECT AVG(finished.duration_ms) avg_duration_ms,
          MAX(finished.duration_ms) max_duration_ms,
      run.*
    FROM wf_log_finished finished 
      LEFT JOIN run USING(run_id)
  WHERE db_threadpool_size >= 3
  GROUP BY ALL;")

data <- factor.experiment(data)
data$db_threadpool_size <- factor(data$db_threadpool_size, levels = unique(data$db_threadpool_size[order(as.integer(data$db_threadpool_size))]))

plot <- ggplot() +
  ylab("Avg. Sync.\nTime [ms]") +
  xlab("Thread Pool Size") +
  #scale_y_log10() +
  scale_x_discrete(guide = guide_axis(check.overlap = TRUE)) +
  facet_nested(
    .~benchmark_name,
    scales = "free_y",
    independent="y"
  ) 
data$t <- paste(data$patch_global_quiescence, data$experiment_commit)
plot <- plot +
  geom_line(
    data = data,
    aes(x = db_threadpool_size,
        y = avg_duration_ms,
        color=experiment_commit,
        linetype=patch_global_quiescence,
        group=t),
    linewidth=0.2
  )


ggplot.save(plot + plot.theme.paper() +
              theme(legend.position = c(0.45,1.55),
                    plot.margin = margin(3, 0.5, 0.5, 0.5, unit="mm"),
                    legend.direction ="horizontal",
                    legend.box = "horizontal",
                    legend.text = element_text(size = FONT.SIZE - 1, margin=margin(l=-5)),
                    legend.key.size = unit(1, "mm"),
                    legend.margin = margin(0,0,0,0),
                    legend.title = element_blank(),
                    legend.background = element_blank(),
                    #axis.text.x = element_text(angle = 20, hjust = 1)
              )
            , paste("Synchronization-Time-Line", sep="-"), width=7.5, height = 2.1, use.grid=FALSE)

