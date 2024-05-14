# MariaDB WfPatch Utils

A utility bash script to (1) compile MariaDB and (2) generate a patch from the compiled units.

Use `git clone --recurse-submodules ...` when cloning this repository. 
**Important**: build kpatch before running this script (`cd kpatch && make clean && make`).


## Compile
Use the script `build` to build the predecessor commit and the given commit. `-b|--build-dir` expected the following directory structure, wheras `-n|--git-name` specifies the name of the DBMS git repository (cloned on disk):

```
- <-b||--build-dir>
    - <-n|--git-name>
    - ...
```

Example:
```
# Preparation
mkdir output
cd build
git clone <URL> mariadb
cd ..

# Directory structure:
# - output
#   - mariadb

./build -b output -n mariadb ...
```

The specified output directory `-o|--output` contains three subdirectories once the script finishes:
```
- <-o|--output>
    - bin
    - build
    - build-new
```

- `bin`: Contains the installation (all executables). This directory might be empty if the flag `./build --no-install` was used.
- `build`: Contains the build of the predecessor commit.
- `build-new`: Contains the build of the specified commit.

## Generate Patch
Use the script `generate-patch` in order to generate a WfPatch patachable patch. The expected directory structure is the output of the `build` script. All patches are stored inside the specified directory.


## Test Patch
Use the script `test-patch` in order to test mariadb server in five different modes to verify if a WfPatch might introduce some errors in mariadbd. In the first mode, mariadb server is tested without applying any patch (as a baseline). In the second and third modes, the server is tested with local and global quiescence respectively, yet the patch is not applied and only the migration occures. Finally, within the last two modes, the server is tested with local and global quiescence while the patch files are applied. The script expects the following flags:

```
-m|--mtr-dir    The root directory of the mysql-test framework in which the mtr script and its unit test files reside.
-p|--patch-dir  The path in which the generated patch files reside.
-s|--suite      The suite name to run. The default is 'innodb'. Specify 'all' to run all of available the suites.
-d|--daemon	    The default is 'mariadbd'. However, 'mysqld' can also be issued.
```
