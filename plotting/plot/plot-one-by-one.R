#!/usr/bin/env -S Rscript --no-save --no-restore

# Uses the experiment "do-as"

source("lib.R")
source("util.R")

read.input.args()

INPUT.FILE.WF <- paste(DUCKDB.FILE, "/patch_one_by_one_wf.csv", sep="")
if (!file.exists(INPUT.FILE.WF)) {
  stop(cat("File", INPUT.FILE.WF, "does not exist!"))
}

INPUT.FILE.DATA <- paste(DUCKDB.FILE, "/patch_one_by_one_raw.csv", sep="")
if (!file.exists(INPUT.FILE.DATA)) {
  stop(cat("File", INPUT.FILE.DATA, "does not exist!"))
}

data <- read.csv(INPUT.FILE.DATA)
percentiles <- quantile(data$latency_ms, c(0.1, 0.9))
data$time_s <- data$start - min(data$start)
data <- data[data$latency_ms >= percentiles[1] & data$latency_ms <= percentiles[2], ]


data$version <- factor(data$version)
# We start with Worker ID at 1, not 0
data$worker <- data$worker + 1
data$worker <- factor(data$worker)

data.wf <- read.csv(INPUT.FILE.WF)
data.wf$time_s <- (data.wf$start - min(data$start)) + (data.wf$latency_ms / 1000)

# Style
plot <- ggplot() +
  ylab("Latency\n[ms]") +
  xlab("Time [s]")

# Bars
plot <- plot +
  geom_point(
    data = data,
    aes(
      x = time_s,
      y = latency_ms,
      color = version,
      shape = worker
    ),
    size=0.5
  ) +
  scale_color_manual(values=c("#ff0000", "#0000ff", "#ffa600", "#a600ff")) +
  scale_shape_manual(values=c(20, 17, 22, 3, 4))

# Patch line
plot <- plot +
  geom_vline(
    data = data.wf,
    aes(xintercept = time_s),
    color = "black",
    linetype = "dashed",
    linewidth = 0.2
  )


plot <- plot + plot.theme.paper() +
  guides(color=guide_legend(title="'SELECT 0;' Result:", order=1),
         #shape=guide_legend(title="Worker ID:", order=2)
         shape="none"
         ) +
  theme(legend.position="top",
        legend.box = "vertical",
        #legend.direction = "vertical", 
        #legend.justification="center",
        #legend.box.just = "left",

        
        legend.margin=margin(0,0,0,-30),
        #legend.spacing = unit(20, "pt"),
        legend.spacing.x = unit(0.3, 'line'),
        legend.spacing.y = unit(0, 'line'),
        legend.box.spacing = unit(3, "pt"),
        legend.box.margin = margin(0, 0, -3, 0),
        #legend.margin = margin(0)),
        legend.key.size = unit(0.5,"line"),
        #legend.key.width = unit(0.2, "line"),
  )


ggplot.save(plot, "Patch-One-by-One", width=7.5, height = 1.9, use.grid = FALSE)

