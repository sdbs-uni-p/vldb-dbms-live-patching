# MariaDB `perf` Analysis

We consider only live patches that affect transaction processing. To determine if a patch has an impact, we use the `do_command` function as a reference, checking if the patched functionality is within its call graph.

By analyzing the performance data, we categorize the possible states as follows:

- **SIBLING**: The patched functionality is contained only in the `do_command` call graph.
- **SIBLING_AND_MORE**: The patched functionality is contained in the `do_command` and other call graphs.
- **NO_SIBLING**: The patched functionality is not contained in the `do_command` call graph.
- **NOT_EXECUTED**: The patched functionality could not be found in any call graph.

We proceed with patches that have a status of SIBLING or SIBLING_AND_MORE.
