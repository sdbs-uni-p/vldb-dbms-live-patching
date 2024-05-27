# Experiments

This directory wraps all experiments performed. Per default, our live patchable commit lists are used (see `~/dbms-live-patching/commits`).

We assume the following hardware requirements:

- Minimum of 300 GB free disk space for experiment data
- Minimum of 384 GB main memory
- Preferable 48 CPU cores (without hyper-threading)

## Linux Kernel

The following steps must be executed using the ***MMView*** Linux kernel.

```
# Inside the VM:
cd ~
./kernel-mmview
sudo reboot
```

## Host System Preparation

To precisely measure (tail) latencies, we performed the following system CPU optimizations:

- Disable Intel Hyper-Threading (in BIOS)
- Operate all CPU cores at maximum frequency.

Execute the following command on the host system to set the CPU frequency of all cores to maximum (even when idle):

```
sudo cpupower frequency-set -g performance

```

Once all experiments were performed, the CPU can be reset:

```
sudo cpupower frequency-set -g schedutil
```

## Experiments

The following commands are assumed to be executed in the VM. Please read the notes for each experiment before performing it (because you may have to adjust some settings based on your hardware).

```
cd ~/dbms-live-patching/experiments
```

The following script wraps all commands given below. Please read all notes of the experiments below and adjust the respective values to your hardware accordingly before execution:

```
./do-all
```

## Notes

### Results

The experiment results are stored in the `~/dbms-live-patching/data` directory. Each experiment is stored in its pre-defined directory. The result directories are linked in the experiment directories.

### MariaDB ([mariadb](mariadb) directory)

- Experiments are defined using configuration files (`config-` prefix). Configuration files can inherit from other configuration files, e.g., all inherit from `config-common.yaml`. The configuration files are parsed by the `patch-benchmark` utility and the defined experiment/benchmark is executed accordingly. 
  - To change the taskset according to your number of available CPU cores, please change the respective values in:
    - `config-one-thread-per-connection.yaml`
    - `config-threadpool.yaml`
- The scripts having the `do-<EXPERIMENT>` prefix execute an experiment and the results are stored in `result-<EXPERIMENT>`.

## MariaDB - Teaser (Figure 1)

```
cd mariadb-one-by-one
./setup
./run
```

## MariaDB - OLTP Benchmarks (Figure 5 and 8)

```
cd mariadb
# Prepare tools
./setup

# Use our benchmark data directories
./download-mariadb-dataset

# One-Thread-per-Connection
./do-noop-one-thread-per-connection
./do-ycsb-one-thread-per-connection
./do-tpcc-one-thread-per-connection

# Thread Pool
./do-noop-threadpool
./do-ycsb-threadpool
./do-tpcc-threadpool
```

## MariaDB - OLAP Benchmarks (Figure 6)

```
cd mariadb

# Setup was already performed
# ./setup

# Download was already performed
# ./download-mariadb-dataset

./do-ch-one-thread-per-connection
```

### Notes

- If our `data-output` directory is not used (`./download-mariadb-dataset`), the dataset for the `ch` benchmark has to be created manually, as we use a slightly modified version of this benchmark (we removed all OLTP queries to gain a pure OLAP workload).

  - ```
    ./create-ch-data-output
    ```

## MariaDB - Synchronization Time (Figure 7)

```
cd mariadb

# Setup was already performed
# ./setup

# Download was already performed
# ./download-mariadb-dataset

./do-every-one-thread-per-connection
./do-every-threadpool
```

## Redis - Impact of database state on maximum query latency (Figure 9)

```
cd redis-fork-vs-wfpatch
./benchmark
```

### Notes

- If you don't have enough main memory available (e.g. when the VM suddenly shuts down/crashes), you can abort this experiment early. To do so, change the upper value (`200`) of this line:

  - ```
    for action_after_sleep in `seq 1 200`; do
    ```

- The script uses CPU pinning. You may adjust it based on your number of CPU cores available:

  - ```
    taskset -c ...
    ```

## MariaDB/Redis - Impact of patch size on patch application time (Figure 10)

### Redis

```
cd redis-all-patches
./benchmark
```

### MariaDB

```
cd mariadb

# Setup was already performed
# ./setup

./do-noop-one-thread-per-connection-all
./do-noop-threadpool-all
```

## MariaDB - Thread Pool comparison: Priority-based quiescence vs WfPatch (original) approach

```
cd mariadb

# Setup was already performed
# ./setup

./do-noop-threadpool-comparison
./do-ycsb-threadpool-comparison
./do-tpcc-threadpool-comparison
```

