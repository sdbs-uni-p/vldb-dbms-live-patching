#!/usr/bin/env -S Rscript --no-save --no-restore

# Uses the experiment "do-as"

source("lib.R")
source("util.R")

args = commandArgs(trailingOnly=TRUE)
if (length(args) != 3) {
  stop("Please specify the DuckDB file to load and the output directory.")
}
# MARIADB.FILE <- "input/one-thread-per-connection-all-patches-load.duckdb"
MARIADB.FILE <<- args[1]
# REDIS.FILE <- "input/redis-all-patches-load.duckdb"
REDIS.FILE <<- args[2]
# OUTPUT.DIR <- "output"
OUTPUT.DIR <<- args[3]

redis.con <<- dbConnect(duckdb::duckdb(), REDIS.FILE, read_only=TRUE)
mariadb.con <<- dbConnect(duckdb::duckdb(), MARIADB.FILE, read_only=TRUE)

COMMITS.TO.ANALAYZE <- NULL

get.mariadb.data <- function(con) {
  df <- dbGetQuery(con,
                  "SELECT
                    sections,
                    size_kib,
                    wf_log_patched.duration_ms as duration_ms,
                    run_id,
                    patch_global_quiescence as global_local
                  FROM (SELECT run_id, COUNT(*) as sections, SUM(size_bytes) / 1024.0 AS size_kib FROM patch_elf GROUP BY ALL)
                    LEFT JOIN wf_log_patched USING(run_id)
                    LEFT JOIN run USING(run_id)
                  GROUP BY ALL;")
  df$patch_global_quiescence <- "Global"
  df$patch_global_quiescence[df$global_local == TRUE] <- "Local"
  df$global_local <- NULL
  df
}

get.redis.data <- function(con) {
  df <- dbGetQuery(con, 
             "SELECT 
                  sections, 
                  size_kib,
                  global_patch_time_ms,
                  local_patch_time_ms,
                  run_id
                FROM (SELECT run_id, COUNT(*) as sections, SUM(size_bytes) / 1024.0 AS size_kib FROM patch_elf WHERE section_name LIKE '.rela%' GROUP BY ALL)
                  LEFT JOIN run USING(run_id)
                GROUP BY ALL;")
  
  df1 <- data.frame(df)
  df1$patch_global_quiescence <- "Global"
  df1$duration_ms <- df1$global_patch_time_ms
  
  df2 <- data.frame(df)
  df2$patch_global_quiescence <- "Local"
  df2$duration_ms <- df2$local_patch_time_ms
  result <- rbind(df1, df2)
  result$local_patch_time_ms <- NULL
  result$global_patch_time_ms <- NULL
  result
}


redis.data <- get.redis.data(redis.con)
redis.data$db <- "Redis"
print(colnames(redis.data))
mariadb.data <- get.mariadb.data(mariadb.con)
mariadb.data$db <- "MariaDB"
print(colnames(mariadb.data))

data <- rbind(redis.data, mariadb.data)

# Style
plot <- ggplot() +
  ylab("Patch\nApplication\nTime [ms]") +
  xlab("Sum over all Section Sizes [KiB]") +
  facet_wrap(db~., scales="free", ncol=2) +
  facetted_pos_scales(x = list(
    scale_x_continuous(trans="sqrt", breaks = c(5, 25, 60, 120, 200)),
    scale_x_continuous(trans="sqrt", breaks = c(50, 200, 500, 900, 1500))
  ))

# Bars
plot <- plot +
  geom_point(data = data,
             aes(
               x = size_kib,
               y = duration_ms,
               color = patch_global_quiescence
             ),
             size = 0.2
  ) +
  #geom_line(data = data,
  #          aes(
  #            x = size_kib,
  #            y = duration_ms,
  #            color = patch_global_quiescence
  #          ),
  #          size = 0.2
  #) +
  scale_colour_manual(labels=c("Global Q", "Local Q"), values=c("orange", "red")) +
  new_scale_colour() +
  geom_smooth(data=data, 
              aes(
                x=size_kib,
                y=duration_ms,
                color=patch_global_quiescence),
              method='lm',
              linetype = "dashed",
              fill=NA,
              size = 0.3) +
  scale_colour_manual(guide="none",values=c("#c78100", "#c70000"))


ggplot.save(plot + plot.theme.paper() +
              theme(legend.position = c(0.475,1.48),
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
              )
            , "ELF-Size", width=7.5, height=2.2, use.grid=FALSE)

