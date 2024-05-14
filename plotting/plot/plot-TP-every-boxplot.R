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
data$db_threadpool_size <- factor(data$db_threadpool_size, levels = unique(data$db_threadpool_size[order(as.integer(data$db_threadpool_size))]))

minmax <- function(x) {
  subset(x, x == max(x) | x == min(x))
}


for (commit in unique(data$experiment_commit_hash)) {
  print(commit)
  data.plot <- data[data$experiment_commit_hash == commit, ]
  
  calculate_whiskers <- function(x, not_used) {
    q <- quantile(x, c(0.25, 0.75))
    iqr <- q[2] - q[1]
    lower_whisker <- max(min(x), q[1] - 1.5 * iqr)
    upper_whisker <- min(max(x), q[2] + 1.5 * iqr)
    return(c(lower_whisker, upper_whisker))
  }
  ylim_expansion <- c(0.3,-0.3)
  quantiles <- c(0, 1)
  ylimglobalnoop <- mapply("-", calculate_whiskers(data.plot$duration_ms[data.plot$patch_global_quiescence == "Global\nQ" & data.plot$benchmark_name == 'NoOp'], quantiles), c(0.05, 0))
  ylimglobalycsb <- mapply("-", calculate_whiskers(data.plot$duration_ms[data.plot$patch_global_quiescence == "Global\nQ" & data.plot$benchmark_name == 'YCSB'], quantiles), ylim_expansion)
  ylimglobaltpcc <- mapply("-", calculate_whiskers(data.plot$duration_ms[data.plot$patch_global_quiescence == "Global\nQ" & data.plot$benchmark_name == 'TPC-C'], quantiles), ylim_expansion)
  ylimlocalnoop <- mapply("-", calculate_whiskers(data.plot$duration_ms[data.plot$patch_global_quiescence == "Local\nQ" & data.plot$benchmark_name == 'NoOp'], quantiles), c(0.1, 0))
  ylimlocalycsb <- mapply("-", calculate_whiskers(data.plot$duration_ms[data.plot$patch_global_quiescence == "Local\nQ" & data.plot$benchmark_name == 'YCSB'], quantiles), ylim_expansion)
  ylimlocaltpcc <- mapply("-", calculate_whiskers(data.plot$duration_ms[data.plot$patch_global_quiescence == "Local\nQ" & data.plot$benchmark_name == 'TPC-C'], quantiles), ylim_expansion)
  
  
  plot <- ggplot() +
    ylab("Sync. Time [ms]") +
    xlab("Thread Pool Size") +
    #scale_y_log10() +
    scale_x_discrete(guide = guide_axis(check.overlap = TRUE)) +
    facet_nested(
      patch_global_quiescence~benchmark_name,
      scales = "free_y",
      independent="y"
    ) +
    facetted_pos_scales(
      y = list(
        patch_global_quiescence == "Global\nQ" & benchmark_name == "NoOp" ~ scale_y_continuous(limits = ylimglobalnoop, guide = guide_axis(check.overlap = TRUE)),
        patch_global_quiescence == "Global\nQ" & benchmark_name == "YCSB" ~ scale_y_continuous(limits = ylimglobalycsb, guide = guide_axis(check.overlap = TRUE)),
        patch_global_quiescence == "Global\nQ" & benchmark_name == "TPC-C" ~ scale_y_continuous(limits = ylimglobaltpcc, guide = guide_axis(check.overlap = TRUE)),
        patch_global_quiescence == "Local\nQ" & benchmark_name == "NoOp" ~ scale_y_continuous(limits = ylimlocalnoop, guide = guide_axis(check.overlap = TRUE)),
        patch_global_quiescence == "Local\nQ" & benchmark_name == "YCSB" ~ scale_y_continuous(limits = ylimlocalycsb, guide = guide_axis(check.overlap = TRUE)),
        patch_global_quiescence == "Local\nQ" & benchmark_name == "TPC-C" ~ scale_y_continuous(limits = ylimlocaltpcc, guide = guide_axis(check.overlap = TRUE))
      )
    )
  
  plot <- plot + geom_boxplot(
    data = data.plot,
    aes(x = db_threadpool_size,
        y = duration_ms),
    position = position_dodge(width = 0.9),
    linewidth=0.2,
    fatten=0.6,
    outlier.shape = NA, 
#    coef = 0
  )
  
  
  ggplot.save(plot + plot.theme.paper() +
                theme(legend.position = c(0.45,1.55),
                      plot.margin = margin(0.5, 0.5, 0.5, 0.5, unit="mm"),
                      legend.direction ="horizontal",
                      legend.box = "horizontal",
                      legend.text = element_text(size = FONT.SIZE - 1, margin=margin(l=-5)),
                      legend.key.size = unit(1, "mm"),
                      legend.margin = margin(0,0,0,0),
                      legend.title = element_blank(),
                      legend.background = element_blank(),
                      panel.spacing.x = unit(0.6, "mm")
                      #axis.text.x = element_text(angle = 20, hjust = 1)
                )
              , paste("Synchronization-Time-Boxplot", commit,sep="-"), width=7.5, height = 2.61, use.grid=FALSE)
}
