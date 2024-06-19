- - # Live Patches Analysis
  
    After building all commits within a specified git commit range and attempting to generate live patches using Kpatch, we analyze the generated patches to check for successful patch generation.
  
    To perform the analysis, execute the following command. `<DIR>` should point to the directory containing all builds of the respective patch crawling tool.
  
    ```
    ./all <DIR>
    ```
  
    This command is equivalent to running the following three commands in sequence:
  
    ```
    ./analyze-kpatch-result <DIR>
    ./partial-success-patch-list <DIR>
    ./success-patch-list <DIR>
    ```
  
    To remove the generated output files, use:
  
    ```
    ./clean
    ```
  
    ## Output Files:
  
    - **commits.success** (`./success-patch-list`)
      - This file lists commit hashes (i.e., source code changes) that can be fully patched.
  
    - **commits.partial** (`./partial-success-patch-list`)
      - This file lists commit hashes (i.e., source code changes) for which only part of the changes can be patched.
  
    - **commits.patches** (`./analyze-kpatch-result`)
      - This file contains a summary (analysis) of the created patches.
