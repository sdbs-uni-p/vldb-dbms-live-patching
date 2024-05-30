These files were collected from the artifacts of Rommel et al. [2].

- Artifact Website: https://www.sra.uni-hannover.de/Publications/2020/WfPatch/index.html
- Direct link to artifacts (a QEMU VM): https://www.sra.uni-hannover.de/Publications/2020/WfPatch/artifact-vm.tar.xz

## File Locations in the QEMU VM (Artifacts of Rommel et al. [2])

Artifacts from Rommel et al. [2] were collected from the following paths in the QEMU VM of Rommel et al. [2]:

- Path: `/home/user/wf-userland`
  - Files: `wf-userland.c`, `wf-userland.h`, `create-patch`
- Path: `/home/user/MariaDB/mariadb`
  - Files:
    - `mariadb-wf-10.3.15.patch` (git hash: `0a415d1674e31712f197bbec1ba4f2a7c349fdf3`)
    - `mariadb-wf-10.5.patch` (git hash: `f93ee51fccc5aea281fbbec59dbafd9b39d78822`)
- Path: `/home/user/wf-userland/kpatch`
  - File: `kpatch.patch` (all commits by Rommel et al. [2] to Kpatch were squashed by us for easier handling)


---

[2] Florian Rommel, Christian Dietrich, Daniel Friesel, Marcel Köppen, ChristophBorchert, Michael Müller, Olaf Spinczyk, and Daniel Lohmann. 2020. *From Global to Local Quiescence: Wait-Free Code Patching of Multi-Threaded Processes*. In Proc. OSDI. 651–666.

