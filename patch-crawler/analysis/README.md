```
./all <DIR> 
# is equal to:
./analyze-kpatch-result <DIR>
./partial-success-patch-list <DIR>
./success-patch-list <DIR>

# Remove the generated output files
./clean
```

Output:
- **commits.success** (`./success-patch-list`)
    - Outputs a list of commit hashes (i.e. source code changes) that can be fully patched.
- commits.partial (`./partial-success-patch-list`)
    - Outputs a list of commit hashes (i.e. source code changes) for which only a part of the changes can be patched.
- commits.patches (`./analyze-kpatch-result`)
    - Contains a summary (analysis) of the created patches.

