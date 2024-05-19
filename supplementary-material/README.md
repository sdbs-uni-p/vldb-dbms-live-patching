# Supplementary Material

This directory contains additional charts for all experiments shown and referenced in our paper.

---

## Overall Queries per Second (QPS)

### Patch ID 1 (`#18502f99eb24f37d11e2431a89fd041cbdaea621`)

This chart is already included in the paper.

![](plots/common/QPS-Bar-wfpatch.patch-18502f99eb24f37d11e2431a89fd041cbdaea621.pdf.png)

### Patch ID 2 (`#30d41c8102c36af7551b3ae77e48efbeb6d7ecea`)

![](plots/common/QPS-Bar-wfpatch.patch-30d41c8102c36af7551b3ae77e48efbeb6d7ecea.pdf.png)

### Patch ID 3 (`#3bb5c6b0c21707ed04f93fb30c654caabba69f06`)

![](plots/common/QPS-Bar-wfpatch.patch-3bb5c6b0c21707ed04f93fb30c654caabba69f06.pdf.png)

### Patch ID 4 (`#56402e84b5ba242214ff4d3c4a647413cbe60ff3`)

![](plots/common/QPS-Bar-wfpatch.patch-56402e84b5ba242214ff4d3c4a647413cbe60ff3.pdf.png)

### Patch ID 5 (`#5b678d9ea4aa3b5ed4c030a9bb5e7d15c3ff8804`)

![](plots/common/QPS-Bar-wfpatch.patch-5b678d9ea4aa3b5ed4c030a9bb5e7d15c3ff8804.pdf.png)

---

## Figure 5

### Patch ID 1 (`#18502f99eb24f37d11e2431a89fd041cbdaea621`)

This chart is already included in the paper.

![](plots/common/QPS-Time-wfpatch.patch-18502f99eb24f37d11e2431a89fd041cbdaea621.pdf.png)

### Patch ID 2 (`#30d41c8102c36af7551b3ae77e48efbeb6d7ecea`)

![](plots/common/QPS-Time-wfpatch.patch-30d41c8102c36af7551b3ae77e48efbeb6d7ecea.pdf.png)

### Patch ID 3 (`#3bb5c6b0c21707ed04f93fb30c654caabba69f06`)

![](plots/common/QPS-Time-wfpatch.patch-3bb5c6b0c21707ed04f93fb30c654caabba69f06.pdf.png)

### Patch ID 4 (`#56402e84b5ba242214ff4d3c4a647413cbe60ff3`)

![](plots/common/QPS-Time-wfpatch.patch-56402e84b5ba242214ff4d3c4a647413cbe60ff3.pdf.png)

### Patch ID 5 (`#5b678d9ea4aa3b5ed4c030a9bb5e7d15c3ff8804`)

![](plots/common/QPS-Time-wfpatch.patch-5b678d9ea4aa3b5ed4c030a9bb5e7d15c3ff8804.pdf.png)

---

## Figure 6

### MariaDB (one-thread-per-connection)

The columns of patch ID 1 and 2 are already included in the paper.

![](plots/one-thread-per-connection/OTPC-CH-Latency-per-Worker-All-Patches.pdf.png)

### MariaDB (thread pool)

This cannot be visualized using a thread pool. The mapping between query <-> worker <-> connection does not exists in this mode, which is required for this kind of chart.

---

## Figure 7

### Setup

Trigger patch application process every 100ms (but without loading a patch).

Each "patch ID" represents a different source code version for MariaDB. Thus, we performed this experiment for each version (but without ultimately loading the patch).

### MariaDB (thread pool)

### Version 1 (`#18502f99eb24f37d11e2431a89fd041cbdaea621`)

This chart is already included in the paper.

![](plots/threadpool/TP-Synchronization-Time-Boxplot-wfpatch.patch-18502f99eb24f37d11e2431a89fd041cbdaea621.pdf.png)

### Version 2 (`#30d41c8102c36af7551b3ae77e48efbeb6d7ecea`)

![](plots/threadpool/TP-Synchronization-Time-Boxplot-wfpatch.patch-30d41c8102c36af7551b3ae77e48efbeb6d7ecea.pdf.png)

### Version 3 (`#3bb5c6b0c21707ed04f93fb30c654caabba69f06`)

![](plots/threadpool/TP-Synchronization-Time-Boxplot-wfpatch.patch-3bb5c6b0c21707ed04f93fb30c654caabba69f06.pdf.png)

### Version 4 (`#56402e84b5ba242214ff4d3c4a647413cbe60ff3`)

![](plots/threadpool/TP-Synchronization-Time-Boxplot-wfpatch.patch-56402e84b5ba242214ff4d3c4a647413cbe60ff3.pdf.png)

### Version 5 (`#5b678d9ea4aa3b5ed4c030a9bb5e7d15c3ff8804`)

![](plots/threadpool/TP-Synchronization-Time-Boxplot-wfpatch.patch-5b678d9ea4aa3b5ed4c030a9bb5e7d15c3ff8804.pdf.png)

### MariaDB (one-thread-per-connection)

### Version 1 (`#18502f99eb24f37d11e2431a89fd041cbdaea621`)

![](plots/one-thread-per-connection/OTPC-Synchronization-Time-Boxplot-wfpatch.patch-18502f99eb24f37d11e2431a89fd041cbdaea621.pdf.png)

### Version 2 (`#30d41c8102c36af7551b3ae77e48efbeb6d7ecea`)

![](plots/one-thread-per-connection/OTPC-Synchronization-Time-Boxplot-wfpatch.patch-30d41c8102c36af7551b3ae77e48efbeb6d7ecea.pdf.png)

### Version 3 (`#3bb5c6b0c21707ed04f93fb30c654caabba69f06`)

![](plots/one-thread-per-connection/OTPC-Synchronization-Time-Boxplot-wfpatch.patch-3bb5c6b0c21707ed04f93fb30c654caabba69f06.pdf.png)

### Version 4 (`#56402e84b5ba242214ff4d3c4a647413cbe60ff3`)

![](plots/one-thread-per-connection/OTPC-Synchronization-Time-Boxplot-wfpatch.patch-56402e84b5ba242214ff4d3c4a647413cbe60ff3.pdf.png)

### Version 5 (`#5b678d9ea4aa3b5ed4c030a9bb5e7d15c3ff8804`)

![](plots/one-thread-per-connection/OTPC-Synchronization-Time-Boxplot-wfpatch.patch-5b678d9ea4aa3b5ed4c030a9bb5e7d15c3ff8804.pdf.png)

---

## Figure 8

Data from Figure 6, but visualized as single latencies.

### MariaDB (one-thread-per-connection)

This chart is already included in the paper.

![](plots/one-thread-per-connection/Latency-Cutout.pdf.png)

### MariaDB (thread pool)

![](plots/threadpool/TP-Latencies-Cutout.pdf.png)

