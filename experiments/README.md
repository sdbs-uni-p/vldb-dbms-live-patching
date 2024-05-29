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

***CAUTION:*** This experiment is ***highly system dependent***, i.e. you may have to tweak some parameters to match your system (all details explained below).

```
cd ~/dbms-live-patching/experiments/redis-fork-vs-wfpatch
./benchmark
```

#### Description

In this experiment, Redis is loaded with data using `SET` requests to achieve a large memory state. While Redis remains under load from these `SET` requests, we perform the following action once, each in a separate run: (1) do nothing, (2) execute a `fork`, and (3) clone an address space. The latency of each `SET` request is measured. This experiment is repeated across 200 different memory states.

##### System Dependent Options

```
# Open the benchmark script, e.g.:
vim benchmark
```

###### Queries per Second

The script makes assumptions about the queries per second (QPS) executed on the system. Here's a high-level overview of how the script functions:

1. Start Redis.
2. Start the Redis benchmark issuing `SET` requests.
3. While the Redis benchmark is running, wait for a certain period to load the memory state.
4. Apply the respective action (nothing, `fork`, or address space cloning) while the benchmark is still active.
5. Wait until the benchmark completes.

It is crucial to perform the respective action while the benchmark is still running. We estimate the total duration of the benchmark based on the queries per second, which depends on the hardware used. The following script illustrates the process in detail (modified slightly for better explanation; the actual code is in the `benchmark` script):

```bash
qps=4500
for load_duration in `seq 1 200`; do
    for method in nothing fork clone; do
        # Add 10 seconds which is needed to perform the action
        total_queries=$((qps * (load_duration + 10)))
				
				# Start Redis
        ./redis-server ... & 
        sleep 2
        
        # Start Redis benchmark
        ./redis-benchmark -t set -n $total_queries ... &
        # Wait $load_duration seconds
        sleep $load_duration
        
        # Perform action
        echo ${method} > /tmp/trigger-redis
```

> Having an accurate QPS value is essential. If the QPS is too low, the Redis benchmark may finish before the action (such as a fork or address space cloning) can be performed. This would prevent the benchmark from recording the latency of these actions or their impact on the client side. Therefore, a precise QPS value is critical.

We provide a small script to determine the number of queries per second on your system:

```bash
./find-qps

# Output:
"test","rps","avg_latency_ms","min_latency_ms","p50_latency_ms","p95_latency_ms","p99_latency_ms","max_latency_ms"
"SET","4606.17","2.158","0.448","2.143","2.191","3.231","5.183"

# 4606.17 represents the number of queries per second (or in Redis terms, requests per second (rps))
```

Please note, we used a QPS value of `4500` in our configuration. Using a higher or lower value may result in more or less memory consumption, respectively.

###### Maximum Main Memory

Running this experiment directly on our server (without using the VM) consumes up to 366 GiB of main memory. Since our server has 374 GiB and the VM introduces additional overhead, the experiment cannot be fully completed in the VM due to insufficient main memory. The following sequence controls the number of memory states used, the higher the number, the larger the memory state:

```bash
for action_after_sleep in `seq 1 200`; do
```

We used an upper value of `175` (instead of `200`) when reproducing this experiment in the VM. This slight modification does not impact the overall result, as the time required for fork/address space cloning increases linearly, which can also be validated with a smaller upper limit.

###### CPU Pinning

The script employs CPU pinning. Adjust it based on the number of CPU cores available:

```bash
taskset -c ...
```

### MariaDB/Redis - Impact of patch size on patch application time (Figure 10)

#### Redis

```
cd ~/dbms-live-patching/experiments/redis-all-patches
./benchmark
```

##### Description

For each crawled patch that is live-patchable, two runs are performed: one applying the patch with local quiescence and one with global quiescence.

#### MariaDB

```
cd ~/dbms-live-patching/experiments/mariadb

# Setup was already performed
# ./setup

./do-noop-one-thread-per-connection-all
./do-noop-threadpool-all
```

##### Description

For each crawled patch that is live-patchable, two runs are performed: one applying the patch with local quiescence and one with global quiescence.

### MariaDB - Thread Pool comparison: Priority-based quiescence vs WfPatch (original) approach

```
cd ~/dbms-live-patching/experiments/mariadb

# Setup was already performed
# ./setup

./do-noop-threadpool-comparison
./do-ycsb-threadpool-comparison
./do-tpcc-threadpool-comparison
```

#### Description

Executes MariaDB with the thread pool policy for our priority-based quiescence approach and for the original thread pool implementation by Rommel et al. The source code modifications for Rommel et al.'s thread pool implementation are located in `~/dbms-live-patching/utils/create-patched-patch-repository/original-mariadb-live-patching`. These modifications were adapted by us to accommodate the new system calls of the MMView Linux kernel, as their original implementation was for the WfPatch Linux kernel (we made this clear with the different git patch files). To clarify, the deadlocks in their implementation are caused by the quiescence points, which is independent of the Linux kernel used and would result in the same issue with the WfPatch Linux kernel.
