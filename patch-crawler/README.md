# Patch Crawler

We crawl the git history of MariaDB and Redis to identify source code changes (commits) that can be patched live. A detailed explanation of the steps executed is provided at the [end of this document](#description). While the process of identifying patches is fully automated, it employs a brute-force method to capture as many live-patchable commits as possible, without accounting for other critical factors such as semantic changes.

> **_NOTE:_** Patch generation is highly system specific. We have noticed slight differences when the following components are deviated from:
>
> - OS: Debian Bullseye (11)
> - GCC version: 10.2.
>
> **MariaDB's crawled live patches can vary slightly due to the use of `ccache` (which speeds up compilation) and `perf`, resulting in non-deterministic outcomes. This may lead to minor differences. In our tests of the reproduction pipeline, we only found differences in a few commits. Nevertheless, since we manually selected the five commits primarily used for the experiments, these discrepancies do not pose a limitation.**


To safe disk space, we do not save any intermediate data. Otherwise several TB of free disk space would be required.

- Approximate **time** until all patches are crawled: **58 hours**
  - MariaDB: 55 hours
  - Redis: 2.5 hours
- Approximate **disk space** used after running all experiments: **470 GB**
  - MariaDB: 445 GB (75 GB patch crawling; 370 GB perf analysis)
  - Redis:  25 GB

## Reproduction Results

You can either crawl live patches using the VM, executing it on the prepared server directly, or using the prepared Docker container. 

### VM

We noticed a crash of the VM when analyzing the commits for MariaDB during the phase of using `perf` to trace the function calls (step 3). We could not find the cause of this crash (no error message, sufficient disk space, free main memory, etc.), but restarting the script from the point where it failed resolved the issue, and the script ran successfully.

### Docker Container in the VM

See the [Docker Container](#docker-container) section for instructions.

## Linux Kernel

Patch crawling should be done using the ***unmodified*** Linux kernel.

```
# Inside the VM:
cd ~
./kernel-regular
sudo reboot
```

## Crawl MariaDB Commit History

Crawling the MariaDB commit history and selecting suitable patches is a multi-step process. Each step creates a list of commits which are potentially patchable, with more restrictions being applied with each step. The commit lists are stored in `~/dbms-live-patching/commits/`.

1. Find commits patchable via Kpatch 
   - MariaDB output: `mariadb.commits.success`
   - Redis output: `redis.commits.success`
2. Apply the MariaDB source code changes (WfPatch integration etc.) to the patchable versions
   - MariaDB output: `mariadb.commits.success.wfpatch` and `mariadb.commits.success.wfpatch.original`
   - Redis output: `redis.commits.success.wfpatch` and `redis.commits.success.wfpatch.original`
3. Analyze MariaDB patches using `perf`, to identify patches that affect a specific functionality of MariaDB.
   - MariaDB output: ` mariadb.commits.success.wfpatch.perf.original`

The following script encompasses all the commands detailed in this section, allowing the entire analysis to be executed automatically. However, it is advisable to review all the steps in this document beforehand to carefully consider the number of parallel builds, as this can significantly impact your system's performance.

```
cd ~/dbms-live-patching/patch-crawler
# Executes all commands of this README for MariaDB
./do-all-mariadb
```

For the detailed steps, we make use of the following variable to specify the directory in which the list of live patchable commits is stored:

```
export RESULT_DIR=~/dbms-live-patching/commits/reproduction
```

### Commits

The directory `~/dbms-live-patching/commits/paper/` contains the commit lists that we have crawled. Please note, the commits in `mariadb.commits.success.wfpatch.perf.paper` were selected manually from `mariadb.commits.success.wfpatch.perf.original` by checking each commit individually.

### 1. Find commits patchable via Kpatch

```
cd ~/dbms-live-patching/patch-crawler/crawl-mariadb
```

The MariaDB git history is crawled by using the commit range specified in the file `commits-to-analyze`. The range should be separated with `..` as the content is injected into a git command. The default range is `mariadb-10.5.0..mariadb-10.5.13` and results in about 4,600 commits to analyze. For each commit, we perform the following steps:

Preparation:

1. Clone MariaDB git repository

Action:

1. Checkout `<PREVIOUS-COMMIT>`
2. Build MariaDB in `build` directory
3. Checkout `<COMMIT>`
4. Build MariaDB in `build-new` directory
5. Try to generate a patch based on `build` and `build-new`.

This process can be executed in parallel by having multiple MariaDB git repositories stored on disk. The following command performs all of the steps:

```
# Per default, 20 MariaDB git repositories are used in parallel:
./crawl
# It is also possible to specify the number of parallel repositories, e.g. use only two:
./crawl 2
```

The script removes both build directories once a commit was analyzed, it only leaves the generated patch and the object files responsible for it, if successful. If the builds should not be deleted, the `--cleanup` flag must be deleted in the `crawl` script when calling `./commits-checker`. 

For a rough estimate of how many parallel repositories should be used and whether build folders should be deleted, here is some data:

- MariaDB git repository: 2.4 GB (20 parallel repositories -> about 48 GB)
- MariaDB build output: 680 MB (4,600 commits; there are two builds per commit -> about 6 TB)

#### ccache

To further speedup builds, ccache is used. The configuration can be found in `~/.ccache.conf`. ccache can use a maximum of 15 GB and cached data is stored in the `/tmp` directory.

#### Output

The output of the `./crawl` script is as follows:

```
output/
	builds/
	patches/
```

The directory `output/builds/` contains all the git repositories used for building MariaDB (these can be deleted after crawling). The `output/patches/` directory contains all analyzed commits and the respective patch files.

#### Patch Analysis

```
cd ~/dbms-live-patching/patch-crawler/analysis
```

The previous step results in a directory containing the generated patches (`output/patches`). When patches for a source code change (i.e. git commit) are generated, there may be two possible states: success and partial success (difference is explained below). Our further analysis uses only commits having the **success** status. 

```
# Analyze all commits
./all ../crawl-mariadb/output/patches
```

This script results in three output files:

```
# For in depth analysis, e.g. how many object files deviated and how many patches could be generated.
commits.analysis
# Contains a list of all commits with the status partial success
commits.partial
# Contains a list of all commits with the status success
commits.success
```

The commits given in `commits.success` are further processed, while the other two files were created for those interested in an in-depth analysis of the commits and generated patches.

> **_NOTE:_** `commits.success` is a list of all git commits that are patchable using Kpatch.

For easier handling, copy the `commits.success` file to the result directory:

```
cp commits.success $RESULT_DIR/mariadb.commits.success
```

##### Success vs Partial Success

A git commit (or a source code change) may affect multiple files. Each file results into its own object file, and Kpatch tries to generate a patch for each deviating object file. If patch generation was successful for **all** deviating object files, its status is **success**. If there is at least one patch, but Kpatch could not generate a patch for all deviating object files, its status is **partial success**.

We illustrate this with the following example:

```
# A source code change affects the files a.c, b.c and c.c. Each file is compiled to its respective object file:

build/
  a.o
  b.o
  c.o
  
build-new/
	a.o
	b.o
	c.o

# Example 1 (success):
# We call this git commit (or patch) as success as it could generate for all deviating object files a patch. The sum of the three patches correspond to the source code change.
output/patches/<COMMIT>/
	patch--a.o
	patch--b.o
	patch--c.o
	
# Example 2 (partial success):
# We call this git commit (or patch) as partial success as it could not generate for all deviating object files a patch.
output/patches/<COMMIT>/
	patch--b.o
```

### 2. Apply the MariaDB source code changes to the patchable versions

```
cd ~/dbms-live-patching/patch-crawler/create-patched-patch-repository
```

We try to automatically apply the MariaDB source code changes (WfPatch integration, quiescence points etc.) to the MariaDB repository. We prepared our source code changes for three different versions of MariaDB for a higher success rate; in particular for git version `mariadb-10.5.0`, `mariadb-10.5.13` and for commit `18502f99eb24f37d11e2431a89fd041cbdaea621`.

```
# Clones the MariaDB repository and tries to apply the source code changes to each given git commit.
./mariadb $RESULT_DIR/mariadb.commits.success
```

This script performs the following steps:

Preparation:

1. Clone the MariaDB repository

Action:

1. Checkout a git commit (one from the list that is passed as an argument)
2. Apply source code changes
3. If successful, it creates a git tag in the form: `wfpatch.patch-<ORIGINAL-COMMIT-HASH>`

Next, we again export all commits as a list for easier handling:

```
cd mariadb-server
# Export a list of all commits
git tag -l | grep wfpatch.patch- > $RESULT_DIR/mariadb.commits.success.wfpatch
# Create the same list without the wfpatch.patch prefix:
cat $RESULT_DIR/mariadb.commits.success.wfpatch | sed 's/^wfpatch\.patch-//' > $RESULT_DIR/mariadb.commits.success.wfpatch.original
```

> **_NOTE:_** `mariadb.commits.success.wfpatch` contains all versions of MariaDB that are live patchable.

### 3. Analyze MariaDB patches using perf

```
cd ~/dbms-live-patching/patch-crawler/mariadb-perf-analysis
```

We want to identify patches that affect transactions of MariaDB, i.e. patches that may have an affect when applied. We perform the following steps:

Preparation:

1. Use the MariaDB repository containing the `wfpatch.patch-<COMMIT>` git tags.
1. Enable tracing of perf events.

Action:

1. Start MariaDB and record (using perf) all function calls
2. Execute the benchmarks: NoOp, YCSB and TPC-C

Once the benchmark is done, we analyze the perf data:

1. Extract the method that is patched.
2. Search for the location of the method in the perf data (i.e. identify its stack trace).
3. Extract all commits for which all patches affect a function in the `do_command` stack trace.

```
# Prepare directory
./setup

# Copy the repository containing the wfpatch.patch-<COMMIT> tags:
mkdir build-dir
rsync -av ../create-patched-patch-repository/mariadb-server/ build-dir/mariadb-wfpatch-commits

# Analyze MariaDB using perf
./check-commit-list $RESULT_DIR/mariadb.commits.success.wfpatch.original

cp sibling.commits $RESULT_DIR/mariadb.commits.success.wfpatch.perf.original
```

>  _**NOTE:**_ Tracing events using perf may not be deterministic. While steps 1 and 2 are deterministic and always lead to the same result, this may not apply to this step. So some commits may deviate when reproducing this step.

### 4. Compare crawler commits with our results

```
cd ~/dbms-live-patching/commits
```

The `diff` script compares the commit lists we originally crawled with the newly generated commit lists from this reproduction step. Please refer to the note at the beginning regarding possible deviations in the commit lists.

```
# Compare all commit lists
./diff
```

## Crawl Redis Commit History

Crawling the Redis Commit History for patchable commits is used similar to MariaDB, please see steps 1, 2 and 4 for details (the `crawl-redis` directory is used for Redis).

---

---

## Docker Container

The Docker container is designed to crawl patches independently of the VM. However, setting up the container may require some adjustments based on the host system's software, such as the possible unavailability of `perf` inside the Docker container. For detailed information and setup instructions, please refer to the [container](container) directory.

---

## Description

The basic functionality of our pipeline for automatically finding live patches based on the development history (git history) is described here. This description applies to MariaDB and Redis.

### 1. Compile & Generate Patch

In the first step, we extract all commits of the git history from a defined range by excluding merge commits. Each extracted git hash represents a pair: the git hash itself (also referred as "new") and its parent (also referred as "old"). Due to the exclusion of merge commits, there is always only one parent. We compile each pair (old and new) and compare the compiled object files of both compilations. If an object file differs between the two versions, we try to generate a patch using the WfPatch modified version of Kpatch. As a consequence, the patch is specific to the pair: The old version of the database can be started and the patch will apply the changes to make the database run in the new version. 

Patch generation is considered successful if (1) object files differ and (2) for **all** deviating object files, a corresponding patch file is created. One deviating object file results in one patch file for live patching. In other words, a commit that makes changes to multiple source code files technically results in multiple patch files.

- For MariaDB (git tag `mariadb-10.5.0` -- `mariadb-10.5.13`), Kpatch was successful for 416 out of 4,613 commits.
- For Redis (git tag `5.0.0` -- `7.0.11`), Kpatch was successful for 937 out of 3,580 commits.

### 2. Source Code Preparation

The code changes, i.e. the implementation of the quiescence points, have to be applied to the respective source code versions since each of the commits found represents a different source code state. To increase the chance of an automatic application of the code changes, it is better to prepare the quiescence points for different source code versions. For MariaDB and Redis, we prepared for each three different git patches that apply the same source code changes. For each application, we used the start, end and a source code version in between of the respective commit range. To automatically apply the changes, we use git patch. Once the source code changes could be applied successfully, the application is compiled again to ensure that the source code modifications did not break the source code.

- For MariaDB, 117 out of 416 source code versions were successfully applied. 
- For Redis, 529 out of 937 source code versions were successfully applied. 

### 3. Stack Tracing (MariaDB only)

The final step ensures that the patched function is also in the stack trace of our quiescence points. This step was done to better manually select the five patches (patch ID~\#1 -- ID~\#5) for MariaDB.

After applying the source code changes, we want to ensure that the patched function is at least executed and a function that is in the call stack of `do_command`. For this, we compile MariaDB with debug flags and execute it while tracing all function calls using `perf`. We execute the benchmarks NoOp, YCSB and TPC-C once to generate some load and to monitor the function paths that are executed. 

Subsequently, we check whether the functions affected by the patch exists in the recorded trace data: We compare the compiled object files of the old and the new version, that make up the patch, and extract the name of all changed function names. These names are checked whether they exist in the `perf` data. Additionally, we keep only patches for which the function is at least in the call tree of `do_command`, which finally resulted in 17 patches.

We manually reviewed all 17 patches and checked whether the commit is tracked by MariaDBs bug tracker Jira. For in total eight commits, we found a corresponding entry in Jira and six of them were of type ``Bug''. Five of the bugs affect the core of MariaDB, i.e. resulting in the patches used for our experiments.
