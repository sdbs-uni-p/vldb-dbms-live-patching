#!/usr/bin/env -S Rscript --no-save --no-restore

# Uses the two experiments "one-thread-per-connection" and "threadpool"

source("lib.R")
source("util.R")


data.qps <- function(con) {
  data <- dbGetQuery(
    con,
    "SELECT COUNT(*) as qps, --COUNT(*) / benchmark_log_duration_s as qps,
	           benchmark_log_duration_s,
             run.*
             FROM latencies LEFT JOIN run USING(run_id)
                       LEFT JOIN benchmark USING(run_id)
             GROUP BY ALL;"
  )
  data["qps"] <- data["qps"] / data["benchmark_log_duration_s"]
  data <- factor.experiment(data)
  data
}

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


data.one <- data.qps(con.one)
data.pool <- data.qps(con.pool)

data.one$identifier <- "One-Th.-Per-Conn."
data.pool$identifier <- "Thread Pool"

data <- rbind(data.one, data.pool)

# Plot for each commit

plot.data <- data
# Style
plot <- ggplot() +
  ylab("kQueries per Second") +
  xlab("Patch Time [s]") +
  facet_nested(
    benchmark_name ~ identifier + experiment_commit,
    scales = "free_y"
  )

# Bars
plot <- plot +
  geom_bar(
    data = plot.data,
    aes(
      x = patch_time_s,
      y = qps / 10 ** 3,
      fill = patch_global_quiescence
    ),
    stat = "identity",
    position = position_dodge2(width = 0.9, preserve = "single")
  ) +
  scale_fill_manual(values = c("blue", "orange", "red"))


# width=15, height = 18, use.grid=FALSE
ggplot.save(plot + plot.theme.paper() +
              theme(legend.position = c(0.5,1.28),
                    plot.margin = margin(3, 0.5, 0.5, 0.5, unit="mm"),
                    axis.text.x = element_text(angle = -50, hjust = -0.3),
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
            , paste("arxiv-QPS-Bar", sep="-"), width=16, height = 4.3, use.grid=FALSE)
