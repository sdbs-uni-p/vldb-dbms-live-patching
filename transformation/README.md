# Data Transformation

We make use of DuckDB to analyze the benchmark data. The scripts in this directory transform the raw benchmark result into DuckDB databases.

> **_NOTE:_** It is important to use DuckDB with the unmodified Linux kernel. We have experienced unforeseen crashes of DuckDB related to the MMView Linux kernel.

## Linux Kernel

The following steps must be executed using the ***unmodified*** Linux kernel.

```
# Inside the VM:
cd ~
./kernel-regular
sudo reboot
```

## Transformation

The following script transforms the raw data of all results (`~/dbms-live-patching/data/`) into DuckDB databases. The respective database will be stored in the respective experiment result directory (`~/dbms-live-patching/data/result-<EXPERIMENT>/<EXPERIMENT>.duckdb`) :

```
./setup
./transform-all
```

As an experiment can consist of multiple benchmark runs, the transformation process is done in parallel for the different benchmark runs. To adjust the number of parallelism, change the following value in `beder/loader.py`:

```
pool = FutureCollector(ProcessPoolExecutor(max_workers=15))
```





