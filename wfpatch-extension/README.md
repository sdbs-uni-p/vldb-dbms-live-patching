# Extensions to the Artifacts of Rommel et al. [2]

The artifacts of the research of Rommel et al. [2] are available here:
- Website: https://www.sra.uni-hannover.de/Publications/2020/WfPatch/index.html
- Direct link to the artifacts (a QEMU VM): https://www.sra.uni-hannover.de/Publications/2020/WfPatch/artifact-vm.tar.xz

## User Space Library
`wf-userland.c` and `wf-userland.h` define the user space library of the live patching utility of Rommel et al. [2]. Both files in this directory define *our* used user space library as we made several extensions to it (e.g. added support of priorities, adapted the system calls to the new MMView Linux kernel etc.). The *original* user space library of Rommel et al. [2] is contained in the `rommel/` directory. To better visualize our modifications, we also provide a git patch about the difference of our and the original user space library in `diff/0001-wf-userland.patch`.

## Create Patch
The `create-patch` script is a small script to easily generate a patch. We slightly modified the script and enhanced it with more information. The script in this directory defines *our* version, and the original of Rommel et al. [2] can be found in the `rommel/` directory. To better visualize our modifications, we also provide a git patch about the difference of our and the original script in `diff/0001-create-patch.patch`.


## MariaDB
To easly visualize our extension to the MariaDB source code (for git tag `mariadb-10.5.0`), we added a git patch showing the modifications (`mariadb-10.5.0.patch`). We excluded the user space library in this patch for better inspection.

The artifacts of Rommel et al. [2] contained two different source code modifications to MariaDB. We added both versions as git patch to the `rommel/` directory (`mariadb-wf-10.3.15.patch` and `mariadb-wf-10.5.patch`). However, we cannot provide a git patch here as we have implemented our source code extension from scratch as explained in our paper.


[2] Florian Rommel, Christian Dietrich, Daniel Friesel, Marcel Köppen, ChristophBorchert, Michael Müller, Olaf Spinczyk, and Daniel Lohmann. 2020. *From Global to Local Quiescence: Wait-Free Code Patching of Multi-Threaded Processes*. In Proc. OSDI. 651–666.
