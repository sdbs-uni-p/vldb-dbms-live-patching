# Plotting

The files are divided into plotting and execution scripts (similar to the experiments, in which we have configuration and execution scripts). The `plot-*.R` scripts contain the R-code to create a plot. The `do-` execute the plotting of an experiment as they contain all information about what data to fetch and what R-script to execute.

The script `do-all` executes all plotting scripts.

General notes:

- `renv` is used to manage the environment.
- The file `INPUT_BASE_DIRECTORY` specifies the directory in which all experiment result directories are stored.
- The file `OUTPUT_DIRECTORY` specifies the directory in which the resulting plots should be stored.

## arXiv 
Scripts prefixed with `arxiv-` are dedicated to generating plots for the arXiv version of the paper. These plots are larger and display all patch IDs for enhanced readability.

