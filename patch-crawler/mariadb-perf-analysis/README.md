Only patches which have an affect on transaction processing are considered. We use the `do_command` function as reference to check whether the patch has an effect (patched functionality is in the call graph of `do_command`).

By extracting the perf data, the following states are possible:
- SIBLING
    - The patched functionality is contained *only* in the `do_command` call graph.
- SIBLING\_AND\_MORE
    - The patched functionality is contained in the `do_command` *and other* call graphs. 
- NO\_SIBLING
    - The patched functionality is *not* contained in the `do_command` call graph.
- NOT\_EXECUTED
    - The patched functionality could *not be found* in any call graph.

We continue with patches of status SIBLING and SIBLING\_AND\_MORE. 

