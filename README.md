# Reproduction Package for the VLDB paper: ***The Case for DBMS Live Patching***

[![DOI: 10.5281/zenodo.11239473](https://zenodo.org/badge/doi/10.5281/zenodo.11239473.svg)](https://doi.org/10.5281/zenodo.11239473)

>  **_NOTE:_** Reproduction package is WIP. A final, stable version should be available around May 31th.

This repository contains all scripts and additional material referenced in the paper. It also contains instructions on how to reproduce the results. Detailed descriptions and instructions are given in the `README.md` of the respective sub-directory.

## Supplementary Material
The directory [supplementary-material](supplementary-material) contains the additional charts referenced in the paper.

## Reproduction Package

The following steps give a high-level overview on how to reproduce this research. 

1. Crawl development history for live patchable source code changes (directory [patch-crawler](patch-crawler)).
2. Perform experiments (directory [experiments](experiments)).
3. Transform experiment data into a DuckDB database (directory [transformation](transformation)).
4. Analyse results and plot charts (directory [plotting](plotting)).

The experiments in step 2 must be performed on a system using the MMView Linux Kernel (https://github.com/luhsra/linux-mmview). The MMView Linux Kernel is an improved version of the original WfPatch Linux Kernel (https://github.com/luhsra/linux-wfpatch). For our research, we used the newer MMView Linux Kernel. lease note that the terms "MMView Linux Kernel" and "WfPatch Linux Kernel" can be used interchangeably.

### VM

We provide a QEMU VM which is equipped (1) with the MMView Linux kernel and (2) all necessary software and libraries installed required for reproducing our results. All steps from above can be carried out within the VM. But please keep in mind that we ran our experiments directly on the system and that the overhang of the virtualization of the VM may result in slightly different measurements (since we paid close attention to latency-sensitive measurements).

For detailed steps about how the VM was created, see the [qemu](qemu) directory.

The following steps get you started using the VM:

```
# 1. Clone Repository
git clone https://github.com/sdbs-uni-p/vldb-dbms-live-patching.git dbms-live-patching

# 2. Go into the qemu directory
cd dbms-live-patching/qemu

# 3. Download and extract QEMU VM
./download-vm

# 4. Run VM
# Note: The script assigns *all available main memory*
# and *all CPU cores except for one core per CPU socket* 
# of the host system to the VM.
./run-vm

# 5. SSH into VM (seeh credentials below)
ssh repro@127.0.0.1 -p 2222

# 6. Download the repository and prepare the used tools
./setup
```

#### Accounts

Accounts (username/password):

- repro/repro
- root/root

> **_NOTE:_** In order to enable easy reproduction, security best practices were neglected. Both users are in the `sudo` group without the need for a password (`NOPASSWD` in `/etc/sudoers`).



### Host System

In case you want to prepare the host system to perform the reproduction, please see the notes in the [qemu](qemu) directory on how to compile the MMView Linux kernel and what software is required. We also provided a Dockerfile for each step (except the experiments) with which the respective step can be executed. However, we offer no guarantee for correct functionality. We tested all steps with the host system directly and inside the VM.

## Steps

A common set of utility tools and scripts is used throughout all steps. These tools have to be prepared before a step is executed.

```
# Prepare common utility tools
cd dbms-live-patching/utils
./setup
```

Once prepared, the steps given above in [Reproduction Package](#reproduction-package) can be executed (see the respective directory for instructions).







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
