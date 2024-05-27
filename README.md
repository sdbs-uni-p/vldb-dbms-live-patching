# Reproduction Package for the VLDB paper: The Case for DBMS Live Patching

> **_NOTE:_** Reproduction package is WIP. A final, stable version should be available around May 31th.

## Supplementary Material
The directory [supplementary-material](supplementary-material) contains the additional charts referenced in the paper.

## Reproduction Package

The following steps describe how to reproduce this research. Each respective directory contains a detailed description of the respective step.

1. Crawl development history for live patches (directory [patch-crawler](patch-crawler))
2. Perform experiments (directory [experiments](experiments))
3. Transform experiment data into a DuckDB database (directory [transformation](transformation))
4. Analyse results and plot charts (directory [plotting](plotting))



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
