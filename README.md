# Reproduction Package for the VLDB paper: ***The Case for DBMS Live Patching***

[![DOI: 10.5281/zenodo.11370684](https://zenodo.org/badge/doi/10.5281/zenodo.11370684.svg)](https://doi.org/10.5281/zenodo.11370684)

This repository contains all scripts and additional material referenced in the paper. It also contains instructions on how to reproduce the results.

## Supplementary Material
The directory [supplementary-material](supplementary-material) contains the additional charts referenced in the paper.

## Hardware Requirements

To be able to execute this reproduction package, the following hardware is recommended:

- At least 1 TB of free disk space
- At least 384 GB of main memory
- At least 30 CPU cores (40 cores or more are recommended)

The entire reproduction pipeline takes about 160 hours.

## Reproduction Pipeline

The following steps provide a high-level overview of how to reproduce this research. Please see the respective sub-directory for in-depth details about the commands to execute:

0. **Initial**: Prepare the system (directory [qemu](qemu)).
1. **Crawl Development History**: Identify live patchable source code changes (directory [patch-crawler](patch-crawler)).
2. **Perform Experiments**: Conduct the experiments (directory [experiments](experiments)).
3. **Transform Experiment Data**: Convert experiment data into a DuckDB database (directory [transformation](transformation)).
4. **Analyze Results and Plot Charts**: Analyze the results and generate plots (directory [plotting](plotting)).

> **_NOTE:_** The README is designed for executing all commands within the QEMU VM. However, these commands can be easily adapted for use on your own prepared system.

The experiments in step 2 must be performed on a system using the MMView Linux kernel (https://github.com/luhsra/linux-mmview; git hash `ecfcf9142ada6047b07643e9fa2afe439b69a5f0`). The MMView Linux kernel is an improved version of the original WfPatch Linux kernel (https://github.com/luhsra/linux-wfpatch). For our research, we used the newer MMView Linux kernel. Please note that the terms "MMView Linux kernel" and "WfPatch Linux kernel" can be used interchangeably.

We provide the results from our experiments, so step 1 or steps 2 and 3 can be skipped. This means experiments can be performed directly, or plots can be generated immediately (but you may have to move/rename some directories to match the expected names/locations).

## Hardware

We conducted our experiments on a Dell PowerEdge R640 server equipped with:

- CPU: 2x Intel Xeon Gold 6248R
  - 24 cores/48 threads per CPU
  - 3.0 GHz
- Main Memory: 384 GB (12x 32 GB)
- Disk: 3.0 TB SSD

> **_NOTE:_** Our experiments use CPU pinning tailored to the specific number of CPU cores in our hardware. You may need to adjust the pinning to match your hardware configuration. Detailed instructions for these adjustments are provided in the steps as needed.

## System Optimizations

To precisely measure (tail) latencies, we performed the following system optimizations:

- Disable Intel Hyper-Threading (in BIOS)
- Operate all CPU cores at maximum frequency (see commands below)
- Map the `/tmp` directory to main memory

### CPU Core Frequency

Execute the following commands on the host system (Linux) to set the CPU frequency of all cores to maximum (even when idle):

```
sudo cpupower frequency-set -g performance

```

Once all experiments were performed, the CPU can be reset:

```
sudo cpupower frequency-set -g schedutil
```

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

> **_NOTE:_** When using one of the `download-` scripts, the data is downloaded, extracted and the downloaded archive gets deleted.

### raw vs. transformed data

The raw data from most experiments is transformed into a DuckDB database, which is then used for all subsequent analysis and plotting. However, some experiment data is directly used for analysis and plotting without being converted into a DuckDB database. All data used for analysis and plotting is included in the "transformed" data.

 The "raw" data includes the original data from which the DuckDB databases were created and is provided for reference.

## WfPatch Extension

Please refer to the [wfpatch-extension](wfpatch-extension) directory for a detailed overview of our extensions to the WfPatch user space library, as well as the original work by Rommel et al. [2]. To ensure clarity regarding the distinctions between the original work and our contributions, we have created this directory. Here, we explicitly outline the nature and extent of our modifications, as it is not always feasible to differentiate these changes directly within the reproduction package.

[2] Florian Rommel, Christian Dietrich, Daniel Friesel, Marcel Köppen, ChristophBorchert, Michael Müller, Olaf Spinczyk, and Daniel Lohmann. 2020. *From Global to Local Quiescence: Wait-Free Code Patching of Multi-Threaded Processes*. In Proc. OSDI. 651–666.

## Directory Overview

- `supplementary-material/`
  - Contains all supplementary material mentioned/referenced in the paper.
- `qemu/`
  - Location for the QEMU VM.
- `patch-crawler/`
  - Contains all scripts to crawl the development history of MariaDB and Redis for live patchable commits.
- `commits/`
  - Contains lists of live patchable commits of MariaDB and Redis, crawled by the scripts in  `patch-crawler/`
- `experiments/`
  - Contains all scripts to run experiments.
- `data/`
  - Contains empty directories in which the results of the experiments will be stored.
- `transformation/`
  - Contains scripts to transform experiment data into DuckDB databases.
- `plotting/`
  - Contains all scripts to analyze the (transformed) benchmark data and to create plots.
- `plots/`
  - Contains a directory in which all plots will be stored.
- `wfpatch-extension`/
  - Highlights our extensions to the WfPatch user space library and other scripts.
- `utils/`
  - Utility scripts used in different steps of the reproduction pipeline.


## TODOs:
- VM: Install Docker
- VM: Map /tmp to /tmpfs
- VM: Fix ccache config (size vs maxsize)
- Upload pre-built Docker image for patch crawling
