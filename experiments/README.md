# Experiments

This directory wraps all experiments performed. Per default, our live patchable commit lists are used (see `~/dbms-live-patching/commits`).

## Linux Kernel

The experiments must be executed using the ***MMView*** Linux kernel.

```
# Inside the VM:
cd ~
./kernel-mmview
sudo reboot
```

## Experiments

Please set the CPU core frequency of the host system to maximum (on host system: `sudo cpupower frequency-set -g performance`). 

The following script encompasses all the commands detailed in this section, allowing all experiments to be executed automatically. However, it is advisable to review all the steps in this document beforehand to make adjustments to certain hardware dependent settings.

```
cd ~/dbms-live-patching/experiments
# Executes all experiments. This command may take several days to finish.
./do-all
```

### Notes

#### Experiment Results

The results of the experiments are stored in the `~/dbms-live-patching/data` directory. Each experiment has its own predefined directory within this location. Additionally, the result directories are linked within the respective experiment directories for easy access.

#### MariaDB ([mariadb](mariadb) directory)

- Experiments are defined using configuration files prefixed with `config-`. These files can inherit settings from other configuration files, such as `config-common.yaml`. The `patch-benchmark` utility parses these configuration files, executing the defined experiment or benchmark accordingly.
  - To adjust the CPU taskset based on the available number of CPU cores, modify the respective values (`taskset_start`, `taskset_end`, and `taskset_step`) in:
    - `config-one-thread-per-connection.yaml`
    - `config-threadpool.yaml`
- Scripts prefixed with `do-<EXPERIMENT>` execute a specific experiment, with the results stored in directories labeled `result-<EXPERIMENT>`.
- `./download-mariadb-dataset` downloads the MariaDB database directories used by us. We recommend to execute this command before starting the experiments, to perform the benchmarks on the exactly same dataset.
- The `benchbase-config/` directory contains the configuration files of BenchBase (benchmark framework).

### MariaDB - Teaser (Figure 1)

```
cd ~/dbms-live-patching/experiments/mariadb-one-by-one
./setup
./run
```

#### Description

Live patching of MariaDB through four code versions while scaling the number of connections. The directory `mariadb-git-patches/` contains the custom crafted code changes (which modify the result of the `SELECT 1` query). 

### MariaDB - OLTP Benchmarks (Figure 5 and 8)

```
cd ~/dbms-live-patching/experiments/mariadb

# Prepare tools
./setup

# Use our database directories
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

#### Description

Executes the NoOp, YCSB and TPC-C benchmark against MariaDB. Each benchmark is executed five times, while the patch is applied at a different time (after 5, 10, 15, 20 and 25 seconds). All of this is done for the global and local quiescence method and for all five patches of MariaDB, i.e. for all five different versions of MariaDB.

### MariaDB - OLAP Benchmarks (Figure 6)

```
cd ~/dbms-live-patching/experiments/mariadb

# Setup was already performed
# ./setup

# Download was already performed
# ./download-mariadb-dataset

# If the download of the dataset was *NOT* performed, 
# create the ch-dataset before executing the benchmark:
# ./create-ch-data-output

./do-ch-one-thread-per-connection
```

#### Description

Executes a customized version of the CH-benCHmark, concentrating solely on OLAP queries. Refer to `benchbase-config/benchbase-ch-10-config.xml` for precise configuration details. The modified benchmark runs across all five patches of MariaDB, with one run employing global quiescence and another run using local quiescence.

> Note: It's advisable to download the provided MariaDB database directories for accurate execution. To do so, execute `./download-mariadb-dataset`, resulting in the creation of the `data-output/` directory. This directory stores datasets for all MariaDB versions and benchmarks, facilitating dataset reuse for subsequent benchmark executions.

Typically, the BenchBase configuration file used for benchmarking also handles dataset loading. However, since the OLTP portion of the CH-benCHmark configuration has been removed, standard dataset loading isn't feasible. Hence, the `benchbase-config/benchbase-ch-10-load-config.xml` configuration file is utilized for dataset loading. Dataset creation is automated via `./create-ch-data-output`.

### MariaDB - Synchronization Time (Figure 7)

```
cd ~/dbms-live-patching/experiments/mariadb

# Setup was already performed
# ./setup

# Download was already performed
# ./download-mariadb-dataset

# One-Thread-per-Connection
./do-noop-one-thread-per-connection-every
./do-ycsb-one-thread-per-connection-every
./do-tpcc-one-thread-per-connection-every

# Thread Pool
./do-noop-threadpool-every
./do-ycsb-threadpool-every
./do-tpcc-threadpool-every
```

#### Description

Executes the NoOp, YCSB, and TPC-C benchmarks while triggering patch application every 0.1 seconds, although no actual patch is applied. This process is carried out across all five versions of MariaDB. Additionally, various thread pool sizes are employed for the thread pool connection policy, as specified in `config-threadpool-every.yaml`.

### Redis - Impact of database state on maximum query latency (Figure 9)

```
cd redis-fork-vs-wfpatch
./benchmark
```

#### Notes

- Running this experiment directly on our server (without using the VM) consumes up to 366 GiB of main memory. Since our server has 374 GiB and the VM introduces additional overhead, the experiment cannot be fully completed in the VM due to insufficient main memory.
  
  - To avoid running through all configured options, you can modify the following line:

    ```bash
    for action_after_sleep in `seq 1 200`; do
    ```

    We used an upper value of `175` (instead of `200`) when reproducing this experiment in the VM. This slight modification does not impact the overall result, as the time required for fork/address space cloning increases linearly, which can also be validated with a smaller upper limit.

- The script employs CPU pinning. Adjust it based on the number of CPU cores available:

  ```bash
  taskset -c ...
  ```

### MariaDB/Redis - Impact of patch size on patch application time (Figure 10)

#### Redis

```
cd ~/dbms-live-patching/experiments/redis-all-patches
./benchmark
```

#### MariaDB

```
cd ~/dbms-live-patching/experiments/mariadb

# Setup was already performed
# ./setup

./do-noop-one-thread-per-connection-all
./do-noop-threadpool-all
```

### MariaDB - Thread Pool comparison: Priority-based quiescence vs WfPatch (original) approach

```
cd ~/dbms-live-patching/experiments/mariadb

# Setup was already performed
# ./setup

./do-noop-threadpool-comparison
./do-ycsb-threadpool-comparison
./do-tpcc-threadpool-comparison
```

