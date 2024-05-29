# Reproduction Package for the VLDB paper: ***The Case for DBMS Live Patching***

[![DOI: 10.5281/zenodo.11370684](https://zenodo.org/badge/doi/10.5281/zenodo.11370684.svg)](https://doi.org/10.5281/zenodo.11370684)

This repository contains all scripts and additional material referenced in the paper. It also contains instructions on how to reproduce the results. Detailed descriptions and instructions are given in the `README.md` of the respective sub-directory.

## Supplementary Material
The directory [supplementary-material](supplementary-material) contains the additional charts referenced in the paper.

## Reproduction Pipeline

The following steps provide a high-level overview of how to reproduce this research:

0. **Initial**: Prepare the system (directory [qemu](qemu)).
1. **Crawl Development History**: Identify live patchable source code changes (directory [patch-crawler](patch-crawler)).
2. **Perform Experiments**: Conduct the experiments (directory [experiments](experiments)).
3. **Transform Experiment Data**: Convert experiment data into a DuckDB database (directory [transformation](transformation)).
4. **Analyze Results and Plot Charts**: Analyze the results and generate plots (directory [plotting](plotting)).

The experiments in step 2 must be performed on a system using the MMView Linux kernel (https://github.com/luhsra/linux-mmview; git hash `ecfcf9142ada6047b07643e9fa2afe439b69a5f0`). The MMView Linux kernel is an improved version of the original WfPatch Linux kernel (https://github.com/luhsra/linux-wfpatch). For our research, we used the newer MMView Linux kernel. Please note that the terms "MMView Linux kernel" and "WfPatch Linux kernel" can be used interchangeably.

We provide our results, so step 1 or steps 2 and 3 can be skipped. This means experiments can be performed directly, or plots can be generated immediately (but you may have to move/rename some directories to match the expected names/locations).

## Original Data

We provide our results in Zenodo (https://doi.org/10.5281/zenodo.11370684). 

- Raw experiment data: 
  - https://zenodo.org/records/11370684/files/raw-data.tar.xz
  - `./download-raw-data`
- Transformed experiment data:
  - https://zenodo.org/records/11370684/files/transformed-data.tar.xz
  -  `./download-transformed-data`
- Download MariaDB database directories:
  - https://zenodo.org/records/11370684/files/data-output.tar.xz
  -  `./experiments/mariadb/download-mariadb-dataset`
