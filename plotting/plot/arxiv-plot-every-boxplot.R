#!/usr/bin/env -S Rscript --no-save --no-restore

source("lib.R")
source("util.R")

args = commandArgs(trailingOnly=TRUE)
if (length(args) != 3) {
  stop("Please specify the DuckDB file to load and the output directory.")
}

# DUCKDB.POOL.FILE <- "input/threadpool-every-0.1.duckdb"
DUCKDB.POOL.FILE <- args[1]
# DUCKDB.ONE.FILE <- "input/one-thread-per-connection-every-0.1.duckdb"
DUCKDB.ONE.FILE <- args[2]
# OUTPUT.DIR <- "output" 
OUTPUT.DIR <- args[3]

con.one <- dbConnect(duckdb::duckdb(), DUCKDB.ONE.FILE, read_only=TRUE)
con.pool <- dbConnect(duckdb::duckdb(), DUCKDB.POOL.FILE, read_only=TRUE)


data.one <- dbGetQuery(con.one, 
  "SELECT finished.duration_ms,
      run.*
    FROM wf_log_finished finished 
      LEFT JOIN run USING(run_id);")

data.one <- factor.experiment(data.one)
data.one$db_threadpool_size <- factor(data.one$db_threadpool_size)

data.pool <- dbGetQuery(con.pool, 
                       "SELECT finished.duration_ms,
      run.*
    FROM wf_log_finished finished 
      LEFT JOIN run USING(run_id);")

data.pool <- factor.experiment(data.pool)
data.pool$db_threadpool_size <- factor(data.pool$db_threadpool_size, levels = unique(data.pool$db_threadpool_size[order(as.integer(data.pool$db_threadpool_size))]))

minmax <- function(x) {
  subset(x, x == max(x) | x == min(x))
}

data.one$identifier <- "One-Th.-Per-Conn."
data.pool$identifier <- "Thread Pool"
data <- rbind(data.one, data.pool)

data.plot <- data

calculate_whiskers <- function(x, not_used) {
  q <- quantile(x, c(0.25, 0.75))
  iqr <- q[2] - q[1]
  lower_whisker <- max(min(x), q[1] - 1.5 * iqr)
  upper_whisker <- min(max(x), q[2] + 1.5 * iqr)
  return(c(lower_whisker, upper_whisker))
}
ylim_expansion <- c(0.3,-0.3)
quantiles <- c(0, 1)
ylimglobalnoopTP <- mapply("-", calculate_whiskers(data.plot$duration_ms[data.plot$identifier == "Thread Pool" & data.plot$patch_global_quiescence == "Global Q" & data.plot$benchmark_name == 'NoOp'], quantiles), c(0.05, 0))
ylimglobalycsbTP <- mapply("-", calculate_whiskers(data.plot$duration_ms[data.plot$identifier == "Thread Pool" & data.plot$patch_global_quiescence == "Global Q" & data.plot$benchmark_name == 'YCSB'], quantiles), ylim_expansion)
ylimglobaltpccTP <- mapply("-", calculate_whiskers(data.plot$duration_ms[data.plot$identifier == "Thread Pool" & data.plot$patch_global_quiescence == "Global Q" & data.plot$benchmark_name == 'TPC-C'], quantiles), ylim_expansion)
ylimlocalnoopTP <- mapply("-", calculate_whiskers(data.plot$duration_ms[data.plot$identifier == "Thread Pool" & data.plot$patch_global_quiescence == "Local Q" & data.plot$benchmark_name == 'NoOp'], quantiles), c(0.1, 0))
ylimlocalycsbTP <- mapply("-", calculate_whiskers(data.plot$duration_ms[data.plot$identifier == "Thread Pool" & data.plot$patch_global_quiescence == "Local Q" & data.plot$benchmark_name == 'YCSB'], quantiles), ylim_expansion)
ylimlocaltpccTP <- mapply("-", calculate_whiskers(data.plot$duration_ms[data.plot$identifier == "Thread Pool" & data.plot$patch_global_quiescence == "Local Q" & data.plot$benchmark_name == 'TPC-C'], quantiles), ylim_expansion)

ylimglobalnoopOTPC <- mapply("-", calculate_whiskers(data.plot$duration_ms[data.plot$identifier == "One-Th.-Per-Conn." & data.plot$patch_global_quiescence == "Global Q" & data.plot$benchmark_name == 'NoOp'], quantiles), c(0.01, -0.01))
ylimglobalycsbOTPC <- mapply("-", calculate_whiskers(data.plot$duration_ms[data.plot$identifier == "One-Th.-Per-Conn." & data.plot$patch_global_quiescence == "Global Q" & data.plot$benchmark_name == 'YCSB'], quantiles), ylim_expansion)
ylimglobaltpccOTPC <- mapply("-", calculate_whiskers(data.plot$duration_ms[data.plot$identifier == "One-Th.-Per-Conn." & data.plot$patch_global_quiescence == "Global Q" & data.plot$benchmark_name == 'TPC-C'], quantiles), ylim_expansion)
ylimlocalnoopOTPC <- mapply("-", calculate_whiskers(data.plot$duration_ms[data.plot$identifier == "One-Th.-Per-Conn." & data.plot$patch_global_quiescence == "Local Q" & data.plot$benchmark_name == 'NoOp'], quantiles), c(0.01, -0.01))
ylimlocalycsbOTPC <- mapply("-", calculate_whiskers(data.plot$duration_ms[data.plot$identifier == "One-Th.-Per-Conn." & data.plot$patch_global_quiescence == "Local Q" & data.plot$benchmark_name == 'YCSB'], quantiles), ylim_expansion)
ylimlocaltpccOTPC <- mapply("-", calculate_whiskers(data.plot$duration_ms[data.plot$identifier == "One-Th.-Per-Conn." & data.plot$patch_global_quiescence == "Local Q" & data.plot$benchmark_name == 'TPC-C'], quantiles), ylim_expansion)


plot <- ggplot() +
  ylab("Sync. Time [ms]") +
  xlab("Thread Pool Size") +
  #scale_y_log10() +
  scale_x_discrete(guide = guide_axis(check.overlap = TRUE)) +
  facet_nested(
    patch_global_quiescence + benchmark_name ~ identifier + experiment_commit,
    scales = "free",
    independent="y"
  ) +
  facetted_pos_scales(
    y = list(
      identifier == "Thread Pool" & experiment_commit == "ID: 1" & patch_global_quiescence == "Global Q" & benchmark_name == "NoOp" ~ scale_y_continuous(limits = ylimglobalnoopTP, guide = guide_axis(check.overlap = TRUE)),
      identifier == "Thread Pool" & experiment_commit == "ID: 1" & patch_global_quiescence == "Global Q" & benchmark_name == "YCSB" ~ scale_y_continuous(limits = ylimglobalycsbTP, guide = guide_axis(check.overlap = TRUE)),
      identifier == "Thread Pool" & experiment_commit == "ID: 1" & patch_global_quiescence == "Global Q" & benchmark_name == "TPC-C" ~ scale_y_continuous(limits = ylimglobaltpccTP, guide = guide_axis(check.overlap = TRUE)),
      identifier == "Thread Pool" & experiment_commit == "ID: 1" & patch_global_quiescence == "Local Q" & benchmark_name == "NoOp" ~ scale_y_continuous(limits = ylimlocalnoopTP, guide = guide_axis(check.overlap = TRUE)),
      identifier == "Thread Pool" & experiment_commit == "ID: 1" & patch_global_quiescence == "Local Q" & benchmark_name == "YCSB" ~ scale_y_continuous(limits = ylimlocalycsbTP, guide = guide_axis(check.overlap = TRUE)),
      identifier == "Thread Pool" & experiment_commit == "ID: 1" & patch_global_quiescence == "Local Q" & benchmark_name == "TPC-C" ~ scale_y_continuous(limits = ylimlocaltpccTP, guide = guide_axis(check.overlap = TRUE)),
      
      identifier == "Thread Pool" & experiment_commit != "ID: 1" & patch_global_quiescence == "Global Q" & benchmark_name == "NoOp" ~ scale_y_continuous(limits = ylimglobalnoopTP, guide = "none"),
      identifier == "Thread Pool" & experiment_commit != "ID: 1" & patch_global_quiescence == "Global Q" & benchmark_name == "YCSB" ~ scale_y_continuous(limits = ylimglobalycsbTP, guide = "none"),
      identifier == "Thread Pool" & experiment_commit != "ID: 1" & patch_global_quiescence == "Global Q" & benchmark_name == "TPC-C" ~ scale_y_continuous(limits = ylimglobaltpccTP, guide = "none"),
      identifier == "Thread Pool" & experiment_commit != "ID: 1" & patch_global_quiescence == "Local Q" & benchmark_name == "NoOp" ~ scale_y_continuous(limits = ylimlocalnoopTP, guide = "none"),
      identifier == "Thread Pool" & experiment_commit != "ID: 1" & patch_global_quiescence == "Local Q" & benchmark_name == "YCSB" ~ scale_y_continuous(limits = ylimlocalycsbTP, guide = "none"),
      identifier == "Thread Pool" & experiment_commit != "ID: 1" & patch_global_quiescence == "Local Q" & benchmark_name == "TPC-C" ~ scale_y_continuous(limits = ylimlocaltpccTP, guide = "none"),
      
      # One Th. per Conn.
      identifier == "One-Th.-Per-Conn." & experiment_commit == "ID: 1" & patch_global_quiescence == "Global Q" & benchmark_name == "NoOp" ~ scale_y_continuous(limits = ylimglobalnoopOTPC, guide = guide_axis(check.overlap = TRUE)),
      identifier == "One-Th.-Per-Conn." & experiment_commit == "ID: 1" & patch_global_quiescence == "Global Q" & benchmark_name == "YCSB" ~ scale_y_continuous(limits = ylimglobalycsbOTPC, guide = guide_axis(check.overlap = TRUE)),
      identifier == "One-Th.-Per-Conn." & experiment_commit == "ID: 1" & patch_global_quiescence == "Global Q" & benchmark_name == "TPC-C" ~ scale_y_continuous(limits = ylimglobaltpccOTPC, guide = guide_axis(check.overlap = TRUE)),
      identifier == "One-Th.-Per-Conn." & experiment_commit == "ID: 1" & patch_global_quiescence == "Local Q" & benchmark_name == "NoOp" ~ scale_y_continuous(limits = ylimlocalnoopOTPC, guide = guide_axis(check.overlap = TRUE)),
      identifier == "One-Th.-Per-Conn." & experiment_commit == "ID: 1" & patch_global_quiescence == "Local Q" & benchmark_name == "YCSB" ~ scale_y_continuous(limits = ylimlocalycsbOTPC, guide = guide_axis(check.overlap = TRUE)),
      identifier == "One-Th.-Per-Conn." & experiment_commit == "ID: 1" & patch_global_quiescence == "Local Q" & benchmark_name == "TPC-C" ~ scale_y_continuous(limits = ylimlocaltpccOTPC, guide = guide_axis(check.overlap = TRUE)),
      
      identifier == "One-Th.-Per-Conn." & experiment_commit != "ID: 1" & patch_global_quiescence == "Global Q" & benchmark_name == "NoOp" ~ scale_y_continuous(limits = ylimglobalnoopOTPC, guide = "none"),
      identifier == "One-Th.-Per-Conn." & experiment_commit != "ID: 1" & patch_global_quiescence == "Global Q" & benchmark_name == "YCSB" ~ scale_y_continuous(limits = ylimglobalycsbOTPC, guide = "none"),
      identifier == "One-Th.-Per-Conn." & experiment_commit != "ID: 1" & patch_global_quiescence == "Global Q" & benchmark_name == "TPC-C" ~ scale_y_continuous(limits = ylimglobaltpccOTPC, guide = "none"),
      identifier == "One-Th.-Per-Conn." & experiment_commit != "ID: 1" & patch_global_quiescence == "Local Q" & benchmark_name == "NoOp" ~ scale_y_continuous(limits = ylimlocalnoopOTPC, guide = "none"),
      identifier == "One-Th.-Per-Conn." & experiment_commit != "ID: 1" & patch_global_quiescence == "Local Q" & benchmark_name == "YCSB" ~ scale_y_continuous(limits = ylimlocalycsbOTPC, guide = "none"),
      identifier == "One-Th.-Per-Conn." & experiment_commit != "ID: 1" & patch_global_quiescence == "Local Q" & benchmark_name == "TPC-C" ~ scale_y_continuous(limits = ylimlocaltpccOTPC, guide = "none")
      
      
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
                    panel.spacing.x = unit(1.2, "mm")
                    #axis.text.x = element_text(angle = 20, hjust = 1)
              ) +
              force_panelsizes(cols = unit(c(0.6, 0.6, 0.6, 0.6, 0.6, 2.1, 2.1, 2.1, 2.1, 2.1), "cm"))
            , paste("arxiv-Synchronization-Time-Boxplot",sep="-"), width=16, height = 8, use.grid=FALSE)
