# Patch Crawler Docker Container

WIP

# Docker Patch Finder

The docker container uses perf to trace data! You may have to change the settings on your host system:
```
sudo su -c "echo -1 > /proc/sys/kernel/perf_event_paranoid"
```

## Access Container
```
# --privileged is needed for perf
# --tmpfs to improve performance. /tmp directory is heavly used by all scripts
docker run --cap-add=SYS_PTRACE --privileged --tmpfs /tmp -it -d --name <CONTAINER-NAME> patch-finder
docker exec -it -u repro <CONTAINER-NAME> /bin/bash

# IMPORTANT!
source ~/.profile
source ~/.bashrc
```

## Setup
```
./setup
```

## Find Potential Patches
This script searches for potential patches. Every commit of a pre-defined range is checked out, compiled and a patch is generated. 

### Execution
```
cd ~/find-potential-patches
./exec-binary-analysis

cd patch-analysis
./all ../binary-analysis/output/patches
# -> Output

cp commits.success ~/commits.success
```

Tuning Options:
- `exec-binary-analysis` 
    - ... compiles `parallel` MariaDB versions in parallel.
    - ... uses `./binary-analysis .. -t <THREADS>` threads to compile one version of MariaDB.
    - ... specifies the pre-defined range `git rev-list --no-merges <START-RANGE>..<END-RANGE>..` to analyse.

### Output:
- **commits.success**
    - Contains the commit hashes of the commits for which a patch could be created for each change.
    - This file is used for further processing.
- commits.partial 
    - Contains the commit hashes of the commits for which a patch could be created but not for every change.
- commits.patches 
    - Contains a summary (analysis) of the created patches.

## Apply WfPatch Source Code Changes
This script applies the code changes needed for live patching to the source code of MariaDB.

### Execution
```
cd ~/repository-wfpatch-code-application
./setup-mariadb

./create-patch-store -c ~/commits.success -r mariadb-server -p git-patches \
--order-start-branch mariadb-10.5.0 --order-end-branch mariadb-10.5.13 # Optional; May increase performance

cd mariadb-server
git tag -l | grep wfpatch.patch- > ~/wfpatch.success 
```

### Output
- **mariadb-server**
    - The MariaDB server git repository containg tags with prefix `wfpatch.patch-<ORIGINAL-COMMIT-HASH>`. A tag is only created if the code changes of `git-patches/0-default.patch` could be applied/merged automatically to the MariaDB source code.
- **~/wfpatch.success**
    - Contains all commit hashes for which successfully (1) a patch could be generated and (2) the WfPatch code changes could be applied.

## Patch Source Finder
This script checks whether the derived patch affacts a transaction. The version is built, MariaDB is started and three benchmarks (NoOp, YCSB and TPC-C) are executed against MariaDB. During benchmarking, the function trace of MariaDB is recoreded with `perf` and analysed afterwards whether the patched function is in the call hierarchy of a transaction. 

### Execution
We can either perform this step with the modified MariaDB source code or the original MariaDB source code. As the `mmview` kernel is not working inside Docker, we will perform the next step with the original MariaDB source code. But this has small drawbacks: It is not tested whether MariaDB compiles, installs and runs with the WfPatch-modified source code version. Nevertheless, this is tested in the final step when experiments are performed with MariaDB. (Alternatively, the following steps can be performed on a system running `mmview` kernel without being in a Docker container).

```
cat ~/wfpatch.success | sed 's/^wfpatch\.patch-//' > ~/wfpatch.success.original
# Remove all wfpatch.patch- prefixes. See description above for more details.

cd ~/patch-source-finder
./setup

mkdir mariadb-wfpatch-utils/build-dir
# Copy git directory containg the patches
rsync -av ~/repository-wfpatch-code-application/mariadb-server/ mariadb-wfpatch-utils/build-dir/mariadb-wfpatch-commits
./check-commit-list ~/wfpatch.success.original
```

### Output
Only patches which have an affect on transaction processing are considered. We use the `do_command` function as reference to check whether the patch has an effect (patched functionality is in the call graph of `do_command`).

- **perf-data**
    - This directory contains for each commit hash a own sub-directory.
- **perf-data/<HASH>**
    - This directory contains the perf trace files, the patch itself and also the result file which states whether the patch has an effect (i.e. if the patched functionality is executed within the call chain of the threads to be patched).
- **perf-data/<HASH>/SIB-<RESULT>**
    - SIBLING
        - The patch has an effect *only* on the threads to be patched.
    - SIBLING\_AND\_MORE
        - The patch has an effect on the threads to be patched and other threads.
    - NO\_SIBLING
        - The patch has an effect *only* on threads which are *not* patched.
    - NOT\_EXECUTED
        - The patched functionality is not executed at all.
 
