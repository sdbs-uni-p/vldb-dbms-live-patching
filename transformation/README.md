# Data Transformation

Most of our experiment data is transformed into a DuckDB database to perform better and easier analysis. The scripts in this directory transform the raw benchmark results into DuckDB databases.

> **_NOTE:_** It is important to use DuckDB with the ***unmodified*** Linux kernel. We have experienced unforeseen crashes of DuckDB related to the MMView Linux kernel.

- Approximate **time** until all raw data is transformed: **2 hours**
- Approximate **disk space** used for the DuckDB database files: **25 GB**

## Linux Kernel

Data transformation must be executed using the ***unmodified*** Linux kernel.

```
# Inside the VM:
cd ~
./kernel-regular
sudo reboot
```
## Transformation

The following scripts transform the raw data of most results (`~/dbms-live-patching/data/`) into DuckDB databases. The respective DuckDB database will be stored in the respective experiment result directory (`~/dbms-live-patching/data/result-<EXPERIMENT>/<EXPERIMENT>.duckdb`). Before transforming the results, you have to prepare the environment:

```
cd ~/dbms-live-patching/transformation
./setup
```

You can either transform each experiment manually:

```
cd ~/dbms-live-patching/transformation

# data/redis-all-patches-load
./transform-redis-all-patches
./transform-experiment `pwd`/../data/one-thread-per-connection/
./transform-experiment `pwd`/../data/one-thread-per-connection-all-patches-load/
./transform-experiment `pwd`/../data/one-thread-per-connection-ch/
./transform-experiment `pwd`/../data/one-thread-per-connection-every-0.1/
./transform-experiment `pwd`/../data/threadpool/
./transform-experiment `pwd`/../data/threadpool-all-patches-load/
BEDER_RANDOM_RUN_ID=1 ./transform-experiment `pwd`/../data/threadpool-comparison/
./transform-experiment `pwd`/../data/threadpool-every-0.1/
```

Or all of these commands can be executed automatically using the following script:

```
cd ~/dbms-live-patching/transformation
./transform-all
```

> **_NOTE:_** Each benchmark run gets an unique ID assigned, which is calculated based on the experiment configuration. As we run the same configuration for the "threadpool comparison" experiment multiple times, we need to generate a random ID (`BEDER_RANDOM_RUN_ID=1`).

Multiple threads are used for the transformation process as multiple runs can be parsed concurrently. To adjust the number of parallelism, change the following value in `beder/loader.py`:

```
pool = FutureCollector(ProcessPoolExecutor(max_workers=15))
```
## Database Schema

The schema of the database files can be found here:

- All experiments transformed with `transform-experiment`: `beder/queries/create.sql`
- Experiment transformed with `transform-redis-all-patches`: `beder-patch/queries/create.sql`

## Description

Most experiment directories are structured as follows:

```
<EXPERIMENT>
    result-noop
    result-ycsb
    result-tpcc
```

The `beder` tool is responsible for transforming each result directory (e.g., `result-noop`) into a DuckDB database. When you run the `transform-experiment` script, it launches three parallel instances of `beder`, one for each result directory. Consequently, each result directory will have its own DuckDB database file. For example:

```
<EXPERIMENT>
    result-noop
        noop.duckdb
    result-ycsb
        ycsb.duckdb
    result-tpcc
        tpcc.duckdb
```

To minimize the number of database files, all three databases are merged into a single database: `<EXPERIMENT>.duckdb`. This process also deletes the individual result database files to save disk space. The tools in the `duckdb-utils/` directory handle this merging process. All of these steps are handled by the `transform-experiment` script.
