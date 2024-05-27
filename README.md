# Reproduction Package for the VLDB paper: ***The Case for DBMS Live Patching***

[![DOI: 10.5281/zenodo.11239473](https://zenodo.org/badge/doi/10.5281/zenodo.11239473.svg)](https://doi.org/10.5281/zenodo.11239473)

>  **_NOTE:_** Reproduction package is WIP. A final, stable version should be available around May 31th.

This repository contains all scripts and additional material referenced in the paper. It also contains instructions on how to reproduce the results. Detailed descriptions and instructions are given in the `README.md` of the respective sub-directory.

## Supplementary Material
The directory [supplementary-material](supplementary-material) contains the additional charts referenced in the paper.

## Reproduction Package

The following steps give a high-level overview on how to reproduce this research. 

0. Initial: Prepare the system (directory [qemu](qemu)).
1. Crawl development history for live patchable source code changes (directory [patch-crawler](patch-crawler)).
2. Perform experiments (directory [experiments](experiments)).
3. Transform experiment data into a DuckDB database (directory [transformation](transformation)).
4. Analyse results and plot charts (directory [plotting](plotting)).

The experiments in step 2 must be performed on a system using the MMView Linux kernel (https://github.com/luhsra/linux-mmview). The MMView Linux kernel is an improved version of the original WfPatch Linux kernel (https://github.com/luhsra/linux-wfpatch). For our research, we used the newer MMView Linux kernel. lease note that the terms "MMView Linux kernel" and "WfPatch Linux kernel" can be used interchangeably.









## TODO:
.. Instructions about downloading the VM ...

Inside the VM:
```
git clone https://github.com/sdbs-uni-p/vldb-dbms-live-patching.git dbms-live-patching

cd ~/dbms-live-patching/utils
./setup

patch-crawler:
./do-all-redis
./do-all-mariadb

cd ~/dbms-live-patching/results
./diff

sudo vim /etc/default/grub
#GRUB_DEFAULT='Advanced options for Debian GNU/Linux>Debian GNU/Linux, with Linux 5.15.0-0.bpo.3-amd64'
GRUB_DEFAULT='Advanced options for Debian GNU/Linux>Debian GNU/Linux, with Linux 5.15.0-mmview-min'
<ESC>:wq
sudo update-grub
sudo reboot

cd experiments

cd redis-fork-vs-wfpatch
./benchmark

cd redis-all-patches
./benchmark

cd mariadb-one-by-one
./setup
./run

cd mariadb
./setup
# POSSIBILITY TO GET OUR DATASETS - DOWNLOAD data-output FROM SOMEWHERE

```

Repro. Steps:

```
./setup

# ... Crawl Patches

cd ~
./kernel-mmview
sudo reboot

cd ~/dbms-live-patching/experiments
cd redis-fork-vs-wfpatch
./benchmark

cd redis-all-patches
./benchmark

cd mariadb-on-by-one
./setup
./run

```
