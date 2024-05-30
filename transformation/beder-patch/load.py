from contextlib import closing
import pandas as pd
import sys
import os
import patch_data
from duckdb_storage import DuckDBStorage

def extract_data(run: str):
    run_id = os.path.basename(run).split("-")[1]
    print(run_id)

    def get_patched_time(file: str):
        with open(file) as f:
            lines = [line for line in f.readlines() if line.startswith("- [patched")]
            if len(lines) != 1:
                print(f"No or multiple patched lines in {file}. Skipping result.")
                return None
            return float(lines[0].split(",")[1].strip())

    wf_global_patch = get_patched_time(os.path.join(run, "wf_log_1"))
    wf_local_patch = get_patched_time(os.path.join(run, "wf_log_0"))
    if wf_global_patch is None or wf_local_patch is None:
        return None, None

    patches = [os.path.join(run, file) for file in os.listdir(run) if file.startswith("patch--")]
    df_patch_info = patch_data.read_patch_elf(patches)
    df_patch_info["run_id"] = run_id


    df_patch_time = pd.DataFrame(data = {"run_id": [run_id], 
                                         "global_patch_time_ms": [wf_global_patch],
                                         "local_patch_time_ms":[wf_local_patch]})
    return df_patch_time, df_patch_info

def main():
    root_dir = sys.argv[1]
    output = sys.argv[2]
    if not os.path.isdir(root_dir):
        print(f"{root_dir} is not a directory!")
        exit(1)
    if os.path.exists(output):
        print("Output already exists!")
        exit(1)

    runs = [os.path.join(root_dir, file) for file in os.listdir(root_dir)
                if os.path.isdir(os.path.join(root_dir, file))]
    
    storage = DuckDBStorage(output)
    with closing(storage.connect()) as conn:
        conn.create_tables()
        for run in runs:
            df_patch_time, df_patch_info = extract_data(run)
            if df_patch_time is None or df_patch_info is None:
                continue
            storage.insert("run", df_patch_time)
            storage.insert("patch_elf", df_patch_info)

if __name__ == "__main__":
    main()

