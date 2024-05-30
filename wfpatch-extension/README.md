# Extensions to the Artifacts of Rommel et al. [2]

The artifacts from the research by Rommel et al. [2] are available here:
- Website: https://www.sra.uni-hannover.de/Publications/2020/WfPatch/index.html
- Direct link to the artifacts (a QEMU VM): https://www.sra.uni-hannover.de/Publications/2020/WfPatch/artifact-vm.tar.xz

> **_NOTE:_** This directory includes both the original files (e.g., user space library) provided by Rommel et al. [2] and our own modifications. To ensure clarity regarding the distinctions between the original work and our contributions, we have created this section. Here, we aim to explicitly outline the nature and extent of our modifications, as it is not always feasible to differentiate these changes directly within the reproduction package. This section serves to provide transparency and facilitate a clear understanding of the enhancements and adjustments we have implemented.

## User Space Library

The files `wf-userland.c` and `wf-userland.h` define the user space library of the live patching framework by Rommel et al. [2]. The files in this directory represent ***our*** modified version of the user space library, which includes several extensions (e.g., added support for priorities, adapted system calls for the new MMView Linux kernel, etc.). The ***original*** user space library by Rommel et al. [2] is located in the `rommel/` directory. To clearly illustrate our modifications, we provide a git patch detailing the differences between our version and the original library in `diff/0001-wf-userland.patch`.

## Create Patch

The `create-patch` script is a utility for generating patches. We have slightly modified and enhanced this script to include more information. The version in this directory represents ***our*** modified script, while the ***original*** version by Rommel et al. [2] is available in the `rommel/` directory. To clearly illustrate our modifications, we provide a git patch detailing the differences between our version and the original script in `diff/0001-create-patch.patch`.

## MariaDB

To easily visualize our extensions to the MariaDB source code (for git tag `mariadb-10.5.0`), we have provided a git patch showing our modifications (`mariadb-10.5.0.patch`). We excluded the user space library in this patch for better inspection.

The artifacts by Rommel et al. [2] contain two different source code modifications to MariaDB. Both versions are included as git patches in the `rommel/` directory (`mariadb-wf-10.3.15.patch` and `mariadb-wf-10.5.patch`). However, we cannot provide a git patch highlighting the differences between our implementation and theirs, as we implemented our source code extension from scratch. As explained in our paper, we adapted the quiescence points for the one-thread-per-connection policy from Rommel et al. [2], while we developed a novel priority-based quiescence approach for the thread pool policy.

## Kpatch

The extension by Rommel et al. [2] for Kpatch is available as a git patch in `rommel/kpatch.patch`. We did not make further extensions or modifications to Kpatch; instead, we updated the version to 0.9.5 (`kpatch.patch`).

---

[2] Florian Rommel, Christian Dietrich, Daniel Friesel, Marcel Köppen, ChristophBorchert, Michael Müller, Olaf Spinczyk, and Daniel Lohmann. 2020. *From Global to Local Quiescence: Wait-Free Code Patching of Multi-Threaded Processes*. In Proc. OSDI. 651–666.
