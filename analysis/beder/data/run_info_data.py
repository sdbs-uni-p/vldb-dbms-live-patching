from functools import reduce
from typing import Any, List

import pandas as pd
import yaml


def read_run_info_data(file: str) -> pd.DataFrame:
    matchings = [
        ("run_success", ["success"]),
        ("run_db_failure", ["db_failure"]),
        ("run_benchmark_failure", ["benchmark_failure"]),
        ("run_benchmark_timeout", ["benchmark_timeout"]),
        ("experiment_name", ["name"]),
        ("experiment_commit", ["commit"]),
        ("db_taskset_start", ["database", "taskset_start"]),
        ("db_taskset_end", ["database", "taskset_end"]),
        ("db_taskset_step", ["database", "taskset_step"]),
        ("db_threadpool_size", ["database", "threadpool_size"]),
        ("db_flags", ["database", "flags"]),
        ("benchmark_kill_min", ["benchmark", "kill_min"]),
        ("benchmark_name", ["benchmark", "name"]),
        ("benchmark_output_name", ["benchmark", "output_name"]),
        ("benchmark_taskset_start", ["benchmark", "taskset_start"]),
        ("benchmark_taskset_end", ["benchmark", "taskset_end"]),
        ("benchmark_taskset_step", ["benchmark", "taskset_step"]),
        ("benchmark_trigger_signal", ["benchbase", "trigger_signal"]),
        ("benchmark_jvm_heap_size", ["benchbase", "jvm_heap_size"]),
        ("benchmark_jvm_arguments", ["benchbase", "jvm_arguments"]),
        ("patch_global_quiescence", ["patch", "global_quiescence"]),
        ("patch_group", ["patch", "patch_group"]),
        ("patch_skip_patch_file", ["patch", "skip_patch_file"]),
        ("patch_apply_all_patches_at_once", ["patch", "apply_all_patches_at_once"]),
        ("patch_measure_vma", ["patch", "measure_vma"]),
        ("patch_patch_only_active", ["patch", "patch_only_active"]),
        ("patch_single_as_for_each_thread", ["patch", "single_as_for_each_thread"]),
        ("patch_time_s", ["patch", "time"]),
        ("patch_every_s", ["patch", "every"]),
    ]
    with open(file) as f:
        run_info = yaml.safe_load(f)

    def get_attribute(path: List[str]) -> Any:
        return reduce(lambda dic, key: dic[key], path, run_info)

    # This function is used for eg. jvm_arguments, or database flags as we do not store lists in DuckDB
    # DuckDB is capable of lists, but probably the R driver has problems with it.
    def list_to_str(value: Any, separator: str = ";") -> str:
        if isinstance(value, list):
            return separator.join(str(v) for v in value)
        return value

    df_data = {
        db_column: [list_to_str(get_attribute(info_path))]
        for db_column, info_path in matchings
    }
    return pd.DataFrame(df_data)
