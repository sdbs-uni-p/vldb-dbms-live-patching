COMMITS.TO.ANALAYZE <- list("ID: 1" = "wfpatch.patch-18502f99eb24f37d11e2431a89fd041cbdaea621", 
                            "ID: 2" = "wfpatch.patch-30d41c8102c36af7551b3ae77e48efbeb6d7ecea", 
                            "ID: 3" = "wfpatch.patch-3bb5c6b0c21707ed04f93fb30c654caabba69f06", 
                            "ID: 4" = "wfpatch.patch-56402e84b5ba242214ff4d3c4a647413cbe60ff3",
                            "ID: 5" = "wfpatch.patch-5b678d9ea4aa3b5ed4c030a9bb5e7d15c3ff8804")

SHORT.NAMES <- FALSE

read.input.args <- function() {
  args = commandArgs(trailingOnly=TRUE)
  if (length(args) != 2) {
    stop("Please specify the DuckDB file to load and the output directory.")
  }
  DUCKDB.FILE <<- args[1]
  OUTPUT.DIR <<- args[2]
}

create.con <- function() {
  con <<- dbConnect(duckdb::duckdb(), DUCKDB.FILE, read_only=TRUE)
}


factor.experiment <- function(df) {
  if (length(COMMITS.TO.ANALAYZE) > 0) {
    df <- df[df$experiment_commit %in% COMMITS.TO.ANALAYZE, ]
  }
  # patch_time_s and patch_every_s are NONE if no patching is used. Set global_quiesence
  # at is always true or false, even when performing no patching
  df$patch_global_quiescence[is.na(df$patch_time_s) & is.na(df$patch_every_s)] <- "-"
  df$patch_global_quiescence <- factor(df$patch_global_quiescence)
  if (SHORT.NAMES) {
    levels(df$patch_global_quiescence) <-
      list("Base-\nline" = "-",
           "Global\nQ" = TRUE,
           "Local\nQ" = FALSE)
  } else {
    levels(df$patch_global_quiescence) <-
      list("Baseline" = "-",
           "Global Q" = TRUE,
           "Local Q" = FALSE)
  }
  
  df$benchmark_name[str_detect(df$experiment_name, "YCSB active")] <- "ycsb-active"
  
  # 1. Set all "YCSB BIG" benchmarks to benchmark name 'ycsb-big'
  df$benchmark_name[df$benchmark_output_name == "ycsb-big"] <- "ycsb-big"
  # 2. Overwrite all 
  df$benchmark_name[str_detect(df$experiment_name, "YCSB Big active")] <- "ycsb-big-active"
  df$benchmark_name <- factor(df$benchmark_name)
  
  # Filter big
  df <- df[df$benchmark_name != "ycsb-big-active", ]
  df <- df[df$benchmark_name != "ycsb-big", ]
  
  levels(df$benchmark_name) <- list(
    "NoOp" = "noop",
    "YCSB" = "ycsb",
    #"YCSB XL" = "ycsb-big",
    "YCSB2" = "ycsb-active",
    #"YCSB2 XL" = "ycsb-big-active",
    "TPC-C" = "tpcc",
    "TPC-H" = "tpch"
  )
  
  # Factor patch time and sort it
  df$patch_time_s[is.na(df$patch_time_s)] <- "-"
  df$patch_time_s <-
    factor(df$patch_time_s, levels = str_sort(unique(df$patch_time_s), numeric = TRUE))
  
  # We do not use threadpool for every run
  df$db_threadpool_size[is.na(df$db_threadpool_size)] <- "-"
  #df$db_threadpool_size <- factor(df$db_threadpool_size, levels = unique(df$db_threadpool_size[order(df$db_threadpool_size)]))
  
  # Own
  df$own_db_amount_threads <-
    ((df$db_taskset_end - df$db_taskset_start) / df$db_taskset_step) + 1
  df$own_benchmark_amount_threads <-
    ((df$benchmark_taskset_end - df$benchmark_taskset_start) / df$benchmark_taskset_step
    ) + 1
  
  df$experiment_commit_hash <- df$experiment_commit
  df$experiment_commit <- factor(df$experiment_commit)
  #factor.levels.index.commit(df)
  if (length(COMMITS.TO.ANALAYZE) > 0) {
    levels(df$experiment_commit) <- COMMITS.TO.ANALAYZE
  }
  df
}

ggplot.save <- function(plot, file_name, width=3, height=3, use.grid=TRUE, 
                         png=FALSE,
                         pdf=TRUE,
                         svg=FALSE) {
  if (use.grid) {
    width <- ggplot.facet.columns(plot) * width
    height <- ggplot.facet.rows(plot) * height
  }
  if (png) {
    ggsave(
      str_c(file_name, ".png"),
      dpi = 300,
      plot,
      path = OUTPUT.DIR,
      limitsize = FALSE,
      width = width,
      height = height,
      units = "cm"
    )
  }
  if (pdf) {
   ggsave(
      str_c(file_name, ".pdf"),
      dpi = 300,
      plot,
      path = OUTPUT.DIR,
      limitsize = FALSE,
      width = width,
      height = height,
      units = "cm"
    )
  }
  if (svg) {
     ggsave(
       str_c(file_name, ".svg"),
       dpi = 300,
       plot,
       path = OUTPUT.DIR,
       limitsize = FALSE,
       width = width,
       height = height,
       units = "cm"
     )
  }
}

ggplot.facet.columns <- function(plot) {
  length(unique(ggplot_build(plot)$layout$layout$COL))
}

ggplot.facet.rows <- function(plot) {
  length(unique(ggplot_build(plot)$layout$layout$ROW))
}


factor.levels.index.commit <- function(df, commit_length = 12) {
  if (!is.factor(df$experiment_commit)) {
    df$experiment_commit <- factor(df$experiment_commit)
  }
  
  indexed_experiment_commit_levels <- c()
  index <- 1
  for (commit in levels(df$experiment_commit)) {
    if (startsWith(commit, "wfpatch.patch-")) {
      #commit <- sub("wfpatch.patch-", "W-", commit)
      commit <- sub("wfpatch.patch-", "", commit)
      if (commit_length < nchar(commit)) {
        commit <- strtrim(commit, commit_length)
      }
    }
    #indexed_commit <- str_c(index, ": ", commit)
    indexed_commit <- str_c(commit)
    indexed_experiment_commit_levels <-
      append(indexed_experiment_commit_levels, indexed_commit)
    index <- index + 1
  }
  # Order is preserved when creating the list (itartion is done over levels)
  levels(df$experiment_commit) <- indexed_experiment_commit_levels
  df
}

FONT.SIZE <- 6

plot.theme.paper <- function() {
  theme_bw() +
    theme(
      # All
      text=element_text(family="paper"),
      # Style facet grid
      strip.text = element_text(face = "bold")
    ) +
    theme(      
      # Text of ticks
      axis.text = element_text(size=FONT.SIZE),
      # Text of axis
      axis.title = element_text(size = FONT.SIZE, face="bold"),
      # Facet
      strip.text = element_text(size = FONT.SIZE, margin = margin(0.5,0.5,0.5,0.5, "mm")),
      # Title of legend
      legend.title = element_text(size = FONT.SIZE), 
      # Element/item of legend
      legend.text = element_text(size = FONT.SIZE),
    )
}




prepare.patch.latencies <- function(df) {
  df$p_patch_only_latency_us <-
    df$p_patch_latency_us - ifelse(
      is.na(df$p_global_quiescence_latency_us),
      (
        df$p_local_as_switch_latency_us + df$p_local_as_new_latency_us
      ),
      df$p_global_quiescence_latency_us
    )
  
  df
}

invert.hex.color.advanced <-
  function(hex_color, black_white = FALSE) {
    leading_hash <- FALSE
    if (substr(hex_color, 1, 1) == "#") {
      # Remove leading '#'
      hex_color <- sub('.', '', hex_color)
      leading_hash <- TRUE
    }
    
    alpha <- ""
    if (nchar(hex_color) == 8) {
      # Hex contains alpha. E.g. XXXXXX<ALPHA><ALPHA> (last two characters)
      # Preserve alpha, do not invert it.
      alpha <-
        substr(hex_color, nchar(hex_color) - 1, nchar(hex_color))
      hex_color <- substr(hex_color, 0, nchar(hex_color) - 2)
    }
    
    if (black_white) {
      # Black white only
      # https://stackoverflow.com/questions/3942878/how-to-decide-font-color-in-white-or-black-depending-on-background-color/3943023#3943023
      r <- as.integer(as.hexmode(substr(hex_color, 1, 2)))
      g <- as.integer(as.hexmode(substr(hex_color, 3, 4)))
      b <- as.integer(as.hexmode(substr(hex_color, 5, 6)))
      
      c <- function(value) {
        value <- value / 255.0
        if (value <= 0.03928) {
          value / 12.92
        } else {
          ((value + 0.055) / 1.055) ^ 2.4
        }
      }
      
      c_values <- unlist(lapply(list(r, g, b), c))
      L <-
        0.2126 * c_values[[1]] + 0.7152 * c_values[[2]] + 0.0722 * c_values[[3]]
      
      if (L > sqrt(1.05 * 0.05) - 0.05) {
        hex_inverted <- "000000"
      } else {
        hex_inverted <- "FFFFFF"
      }
    } else {
      # Just invert color
      hex_inverted <-
        as.hexmode(bitwXor(as.hexmode(hex_color), as.hexmode(0xFFFFFF)))
      hex_inverted <- toupper(as.character(hex_inverted))
    }
    
    if (nchar(hex_inverted) < 6) {
      # Add leading zeros again
      # E.g. hex_color = "FFFF00" will result in "FF"
      # library(stringr)
      hex_inverted <- str_pad(hex_inverted, 6, pad = "0")
    }
    
    if (leading_hash) {
      paste0("#", hex_inverted, alpha)
    } else {
      paste0(hex_inverted, alpha)
    }
  }
