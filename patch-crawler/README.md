# Patch Crawler

We crawl the MariaDB and Redis git history for live patchable source code changes (commits).

> **_NOTE:_**: Patch generation is highly system specific. We have noticed slight differences when the following components are deviated from:
- OS: Debian Bullseye (11)
- GCC version: 10.2.

We assume the following steps are executed within the VM. At the end of this README, we provide commands using the Docker container.

## Linux Kernel

The following steps should be executed using the ***unmodified*** Linux kernel.

```
# Inside the VM:
cd ~
./kernel-regular
sudo reboot
```

## Crawl MariaDB Commit History

Crawling the MariaDB commit history and selecting suitable patches is a multi-step process:

1. Find commits patchable via Kpatch
2. Apply the MariaDB source code changes (WfPatch integration etc.) to the patchable versions
3. Analyze MariaDB patches using perf, to identify patches that affect a specific functionality of MariaDB.

The following script includes all commands that follow in this section. This means the entire analysis can be carried out fully automatically.

```
# Executes all commands of this README for MariaDB
./do-all-mariadb
```

For the detailed steps, we make use of the following variable to specify the directory in which the list of live patchable commits is stored:

```
export RESULT_DIR="~/dbms-live-patching/commits/reproduction/"
```

### 1. Find commits patchable via Kpatch

```
cd crawl-mariadb
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

The directory `output/builds/` contains all the git repositories used for building MariaDB. The `output/patches/` directory contains all analyzed commits and the respective patch files.

#### Patch Analysis

```
cd analysis
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
cd create-patched-patch-repository
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
cd mariadb-perf-analysis
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

The `diff` script compares the commit lists crawled by us with the newly created commit lists crawled in this reproduction step. There should be no output for any of the given commit lists (except perhaps for perf).

```
# Compare all commit lists
./diff
```

## Crawl Redis Commit History

Crawling the Redis Commit History for patchable commits is used similar to MariaDB, please see steps 1, 2 and 4 for details (the `crawl-redis` directory is used for Redis).

---

## Docker Container

See the [container](container) directory for details.

