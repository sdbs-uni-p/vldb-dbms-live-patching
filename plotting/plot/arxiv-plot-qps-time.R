#!/usr/bin/env -S Rscript --no-save --no-restore

# Uses the two experiments "one-thread-per-connection" and "threadpool"

source("lib.R")
source("util.R")

args = commandArgs(trailingOnly=TRUE)
if (length(args) != 3) {
  stop("Please specify the DuckDB file to load and the output directory.")
}

# DUCKDB.ONE.FILE <- "input/one-thread-per-connection.duckdb"
DUCKDB.ONE.FILE <- args[1]
# DUCKDB.POOL.FILE <- "input/threadpool.duckdb"
DUCKDB.POOL.FILE <- args[2]
# OUTPUT.DIR <- "output" 
OUTPUT.DIR <- args[3]

con.one <- dbConnect(duckdb::duckdb(), DUCKDB.ONE.FILE, read_only=TRUE)
con.pool <- dbConnect(duckdb::duckdb(), DUCKDB.POOL.FILE, read_only=TRUE)

lower_time_window_s <- 2
upper_time_window_s <- 2

data.qps.time <- function(con, time.division = 0.1) {
  print(con)
  data <- dbGetQuery(
    con,
    sqlInterpolate(
      con,
      "
WITH all_ranges AS (
  SELECT UNNEST(GENERATE_SERIES(0, FLOOR((benchmark_log_duration_s - 0.5) / ?gap)::INT)) AS slot,
      run_id
  FROM benchmark
), latency_range AS (
    SELECT FLOOR(time_s / ?gap)::INT AS slot,
        run_id,
    FROM latencies
), latency_count_per_range AS (
    SELECT COUNT(*) AS total_latencies,
           slot,
           run_id
    FROM latency_range
    GROUP BY ALL
), latency_count_per_range_zero AS (
    SELECT COALESCE(total_latencies, 0) AS total_latencies,
           slot,
           run_id
    FROM latency_count_per_range 
        RIGHT JOIN all_ranges USING(run_id, slot)
)
SELECT total_latencies AS qps, 
       slot * ?gap AS start, 
       benchmark_log_patch_time_s,
       run.*
FROM latency_count_per_range_zero
    JOIN run USING(run_id)
    JOIN benchmark USING(run_id)
      WHERE patch_time_s IS NULL
      OR (
        start <= (patch_time_s + ?upper_time_window_s)
        AND start >= (patch_time_s - ?lower_time_window_s)
      );"
    ,
    gap = time.division,
    lower_time_window_s = lower_time_window_s,
    upper_time_window_s = upper_time_window_s
    ))
# See below if you want to use ports!
factor.experiment(data)
}

data.one <- data.qps.time(con.one)
data.pool <- data.qps.time(con.pool)

data.one$th_model <- "One-Th.-Per-Conn."
data.pool$th_model <- "Thread Pool"

data <- rbind(data.one, data.pool)
data <- rbind(
  data %>% filter(patch_global_quiescence %in% c("Baseline", "Global Q")) %>% mutate(name = "Global Q"),
  data %>% filter(patch_global_quiescence %in% c("Baseline", "Local Q")) %>% mutate(name = "Local Q")
)
  


# Plot for each commit

plot.data <- data

ylim_expansion <- c(0, 0)
ylimotpcnoopglobal <- mapply("-", range(plot.data$qps[plot.data$name == "Global Q" & plot.data$th_model == "One-Th.-Per-Conn." & plot.data$benchmark_name == 'NoOp'] / 10**3), ylim_expansion)
ylimotpcycsbglobal <- mapply("-", range(plot.data$qps[plot.data$name == "Global Q" & plot.data$th_model == "One-Th.-Per-Conn." & plot.data$benchmark_name == 'YCSB']/ 10**3), ylim_expansion)
ylimotpctpccglobal <- mapply("-", range(plot.data$qps[plot.data$name == "Global Q" & plot.data$th_model == "One-Th.-Per-Conn." & plot.data$benchmark_name == 'TPC-C']/ 10**3), ylim_expansion)

ylimotpcnooplocal <- mapply("-", range(plot.data$qps[plot.data$name == "Local Q" & plot.data$th_model == "One-Th.-Per-Conn." & plot.data$benchmark_name == 'NoOp'] / 10**3), ylim_expansion)
ylimotpcycsblocal <- mapply("-", range(plot.data$qps[plot.data$name == "Local Q" & plot.data$th_model == "One-Th.-Per-Conn." & plot.data$benchmark_name == 'YCSB']/ 10**3), ylim_expansion)
ylimotpctpcclocal <- mapply("-", range(plot.data$qps[plot.data$name == "Local Q" & plot.data$th_model == "One-Th.-Per-Conn." & plot.data$benchmark_name == 'TPC-C']/ 10**3), ylim_expansion)

ylimtpnoopglobal <- mapply("-", range(plot.data$qps[plot.data$name == "Global Q" & plot.data$th_model == "Thread Pool" & plot.data$benchmark_name == 'NoOp'] / 10**3), ylim_expansion)
ylimtpycsbglobal <- mapply("-", range(plot.data$qps[plot.data$name == "Global Q" & plot.data$th_model == "Thread Pool" & plot.data$benchmark_name == 'YCSB']/ 10**3), ylim_expansion)
ylimtptpccglobal <- mapply("-", range(plot.data$qps[plot.data$name == "Global Q" & plot.data$th_model == "Thread Pool" & plot.data$benchmark_name == 'TPC-C']/ 10**3), ylim_expansion)

ylimtpnooplocal <- mapply("-", range(plot.data$qps[plot.data$name == "Local Q" & plot.data$th_model == "Thread Pool" & plot.data$benchmark_name == 'NoOp'] / 10**3), ylim_expansion)
ylimtpycsblocal <- mapply("-", range(plot.data$qps[plot.data$name == "Local Q" & plot.data$th_model == "Thread Pool" & plot.data$benchmark_name == 'YCSB']/ 10**3), ylim_expansion)
ylimtptpcclocal <- mapply("-", range(plot.data$qps[plot.data$name == "Local Q" & plot.data$th_model == "Thread Pool" & plot.data$benchmark_name == 'TPC-C']/ 10**3), ylim_expansion)

# Style
plot <- ggplot() +
  ylab("kQueries (per 100ms)") +
  xlab("Elapsed Time [s]") +
  facet_nested(
    name + benchmark_name ~ th_model + experiment_commit,
    scales = "free",
    independent = "y",
  ) +
  scale_x_continuous(breaks=c(5, 15, 25)) +
  facetted_pos_scales(
    y = list(
      experiment_commit == "ID: 1" & th_model == "One-Th.-Per-Conn." & benchmark_name == "NoOp" & name == "Global Q" ~ scale_y_continuous(limits = ylimotpcnoopglobal, guide = guide_axis(check.overlap = TRUE)),
      experiment_commit != "ID: 1" & th_model == "One-Th.-Per-Conn." & benchmark_name == "NoOp" & name == "Global Q" ~ scale_y_continuous(limits = ylimotpcnoopglobal, guide = "none"),
      
      experiment_commit == "ID: 1" & th_model == "One-Th.-Per-Conn." & benchmark_name == "NoOp" & name == "Local Q" ~ scale_y_continuous(limits = ylimotpcnooplocal, guide = guide_axis(check.overlap = TRUE)),
      experiment_commit != "ID: 1" & th_model == "One-Th.-Per-Conn." & benchmark_name == "NoOp" & name == "Local Q" ~ scale_y_continuous(limits = ylimotpcnooplocal, guide = "none"),
      
      experiment_commit == "ID: 1" & th_model == "One-Th.-Per-Conn." & benchmark_name == "YCSB" & name == "Global Q" ~ scale_y_continuous(limits = ylimotpcycsbglobal, guide = guide_axis(check.overlap = TRUE)),
      experiment_commit != "ID: 1" & th_model == "One-Th.-Per-Conn." & benchmark_name == "YCSB" & name == "Global Q" ~ scale_y_continuous(limits = ylimotpcycsbglobal, guide = "none"),
      
      experiment_commit == "ID: 1" & th_model == "One-Th.-Per-Conn." & benchmark_name == "YCSB" & name == "Local Q" ~ scale_y_continuous(limits = ylimotpcycsblocal, guide = guide_axis(check.overlap = TRUE)),
      experiment_commit != "ID: 1" & th_model == "One-Th.-Per-Conn." & benchmark_name == "YCSB" & name == "Local Q" ~ scale_y_continuous(limits = ylimotpcycsblocal, guide = "none"),
      
      experiment_commit == "ID: 1" & th_model == "One-Th.-Per-Conn." & benchmark_name == "TPC-C" & name == "Global Q" ~ scale_y_continuous(limits = ylimotpctpccglobal, guide = guide_axis(check.overlap = TRUE)),
      experiment_commit != "ID: 1" & th_model == "One-Th.-Per-Conn." & benchmark_name == "TPC-C" & name == "Global Q" ~ scale_y_continuous(limits = ylimotpctpccglobal, guide = "none"),
      
      experiment_commit == "ID: 1" & th_model == "One-Th.-Per-Conn." & benchmark_name == "TPC-C" & name == "Local Q" ~ scale_y_continuous(limits = ylimtptpcclocal, guide = guide_axis(check.overlap = TRUE)),
      experiment_commit != "ID: 1" & th_model == "One-Th.-Per-Conn." & benchmark_name == "TPC-C" & name == "Local Q" ~ scale_y_continuous(limits = ylimtptpcclocal, guide = "none"),
      
      experiment_commit == "ID: 1" & th_model == "Thread Pool" & benchmark_name == "NoOp" & name == "Global Q" ~ scale_y_continuous(limits = ylimtpnoopglobal, guide = guide_axis(check.overlap = TRUE)),
      experiment_commit != "ID: 1" & th_model == "Thread Pool" & benchmark_name == "NoOp" & name == "Global Q" ~ scale_y_continuous(limits = ylimtpnoopglobal, guide = "none"),
      
      experiment_commit == "ID: 1" & th_model == "Thread Pool" & benchmark_name == "NoOp" & name == "Local Q" ~ scale_y_continuous(limits = ylimtpnooplocal, guide = guide_axis(check.overlap = TRUE)),
      experiment_commit != "ID: 1" & th_model == "Thread Pool" & benchmark_name == "NoOp" & name == "Local Q" ~ scale_y_continuous(limits = ylimtpnooplocal, guide = "none"),
      
      experiment_commit == "ID: 1" & th_model == "Thread Pool" & benchmark_name == "YCSB" & name == "Global Q" ~ scale_y_continuous(limits = ylimtpycsbglobal, guide = guide_axis(check.overlap = TRUE)),
      experiment_commit != "ID: 1" & th_model == "Thread Pool" & benchmark_name == "YCSB" & name == "Global Q" ~ scale_y_continuous(limits = ylimtpycsbglobal, guide = "none"),
      
      experiment_commit == "ID: 1" & th_model == "Thread Pool" & benchmark_name == "YCSB" & name == "Local Q" ~ scale_y_continuous(limits = ylimtpycsblocal, guide = guide_axis(check.overlap = TRUE)),
      experiment_commit != "ID: 1" & th_model == "Thread Pool" & benchmark_name == "YCSB" & name == "Local Q" ~ scale_y_continuous(limits = ylimtpycsblocal, guide = "none"),
      
      experiment_commit == "ID: 1" & th_model == "Thread Pool" & benchmark_name == "TPC-C" & name == "Global Q" ~ scale_y_continuous(limits = ylimtptpccglobal, guide = guide_axis(check.overlap = TRUE)),
      experiment_commit != "ID: 1" & th_model == "Thread Pool" & benchmark_name == "TPC-C" & name == "Global Q" ~ scale_y_continuous(limits = ylimtptpccglobal, guide = "none"),
      
      experiment_commit == "ID: 1" & th_model == "Thread Pool" & benchmark_name == "TPC-C" & name == "Local Q" ~ scale_y_continuous(limits = ylimtptpcclocal, guide = guide_axis(check.overlap = TRUE)),
      experiment_commit != "ID: 1" & th_model == "Thread Pool" & benchmark_name == "TPC-C" & name == "Local Q" ~ scale_y_continuous(limits = ylimtptpcclocal, guide = "none")
    )
  )

plot <- plot +
  geom_line(
    data=plot.data,
    aes(x = start,
        y = qps / 10**3,
        color = patch_global_quiescence,
        group=patch_time_s,
    ),
    
    linewidth=0.3
  ) +
  scale_color_manual(values = c("blue", "darkorange", "red")) +
  geom_vline(
    data = plot.data,
    aes(xintercept = benchmark_log_patch_time_s),
    color = "black",
    linetype = "dashed",
    linewidth = 0.15,
    alpha=0.7
  )



# width=15, height = 18, use.grid=FALSE
ggplot.save(plot + plot.theme.paper() +
              theme(legend.position = c(0.5,1.11),
                    plot.margin = margin(2.5, 0.5, 0.5, 0.5, unit="mm"),
                    axis.title.y = element_text(margin = margin(r=3), hjust=0.6),
                    legend.direction ="horizontal",
                    legend.text = element_text(size = FONT.SIZE - 1, margin=margin(l=-3)),
                    legend.key.size = unit(1, "mm"),
                    legend.margin = margin(0,0,0,0),
                    legend.title = element_blank(),
                    legend.background = element_blank(),
                    # Horizontal spacing between facets
                    panel.spacing.x = unit(0.6, "mm")
              )
            , paste("arxiv-QPS-Time", sep="-"), width=16, height = 8, use.grid=FALSE)
