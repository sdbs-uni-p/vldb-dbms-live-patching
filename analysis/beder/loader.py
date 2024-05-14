import hashlib
import multiprocessing
import os
import random
import sys
from argparse import ArgumentParser, Namespace
from concurrent.futures import ProcessPoolExecutor
from functools import reduce
from typing import Callable, List, Optional

import pandas as pd

import data.wf_log_data as wf_log
from data.benchmark_benchmark_data import (
    read_benchbase_benchmark_data,
    read_benchbase_warmup_done_data,
)
from data.benchmark_data import read_benchbase_data
from data.patch_data import read_patch_elf
from data.run_info_data import read_run_info_data
from duckdb_storage import (
    DuckDBStorage,
    DuckDBStorageThread,
    Storage,
    StorageProcessCollector,
)
from future_collector import FutureCollector

USE_RANDOM_RUN_ID = False


def load_experiment(
    storage: Storage,
    experiment_dir: str,
    run_objects_name: str,
    wf_log_name: str,
    success_only: bool,
) -> None:
    run_dirs = [
        os.path.join(experiment_dir, file)
        for file in os.listdir(experiment_dir)
        if os.path.isdir(os.path.join(experiment_dir, file))
    ]
    if success_only:
        run_dirs = [
            run_dir
            for run_dir in run_dirs
            if os.path.isfile(os.path.join(run_dir, "SUCCESS"))
        ]

    for run_dir in run_dirs:
        load_run(storage, run_dir, run_objects_name, wf_log_name, experiment_dir)


def load_run(
    storage: Storage,
    run_dir: str,
    run_objects_name: str,
    wf_log_name: str,
    experiment_dir: str,
) -> None:
    print(run_dir)
    run_id = load_run_info_data(storage, os.path.join(run_dir, run_objects_name))
    benchmark_start_time = load_benchmark_benchmark_data(storage, run_dir, run_id)
    load_raw_data(storage, run_dir, run_id, benchmark_start_time)
    load_wf_log(storage, os.path.join(run_dir, wf_log_name), run_id)

    patch_files = [
        os.path.join(experiment_dir, file)
        for file in os.listdir(experiment_dir)
        if file.startswith("patch--")
    ]

    if len(patch_files) == 0:
        # patch files may be empty, if skip_patch_files is set to TRUE when benchmarking
        return

    patch_data = pd.DataFrame(
        {
            "name": [os.path.basename(file) for file in patch_files],
            "size_bytes": [os.path.getsize(file) for file in patch_files],
        }
    )
    patch_data["run_id"] = run_id
    storage.insert("patch_file", patch_data)

    elf_data = read_patch_elf(patch_files)
    elf_data["run_id"] = run_id
    storage.insert("patch_elf", elf_data)


def load_benchmark_benchmark_data(storage: Storage, run_dir: str, run_id: str) -> int:
    print("Loading BENCHMARK data")
    patch_data_files = [
        os.path.join(run_dir, file)
        for file in os.listdir(run_dir)
        if file.endswith(".patch.csv")
    ]

    if len(patch_data_files) == 0:
        return
    patch_data_file = patch_data_files[0]

    warmup_data, done_data = read_benchbase_warmup_done_data(patch_data_file)

    warmup_data["run_id"] = run_id
    storage.insert("benchmark_log_warmup", warmup_data)

    done_data["run_id"] = run_id
    storage.insert("benchmark_log_done", done_data)

    config_data_file = [
        os.path.join(run_dir, file)
        for file in os.listdir(run_dir)
        if file.endswith(".config.xml")
    ][0]
    benchmark_data = read_benchbase_benchmark_data(patch_data_file, config_data_file)
    benchmark_data["run_id"] = run_id

    storage.insert("benchmark", benchmark_data)

    return benchmark_data.iloc[0].benchmark_log_start_time


def load_run_info_data(storage: Storage, run_objects_file: str) -> str:
    print("Loading run info data")
    run_data = read_run_info_data(run_objects_file)

    run_hash = hashlib.sha512()
    reduce(
        lambda _, value: run_hash.update(str(value).encode("UTF-8")),
        tuple(run_data.iloc[0].values.flatten().tolist()),
    )
    if USE_RANDOM_RUN_ID:
        run_hash.update(f"{random.random()}".encode("UTF-8"))
    run_id = run_hash.hexdigest()

    run_data["run_id"] = run_id
    storage.insert("run", run_data)
    return run_id


def load_raw_data(storage: Storage, run_dir: str, run_id: str, start_time: int) -> None:
    print("Loading RAW data")
    raw_data_files = [
        os.path.join(run_dir, file)
        for file in os.listdir(run_dir)
        if file.endswith(".raw.csv")
    ]
    if len(raw_data_files) == 0:
        return
    raw_data_file = raw_data_files[0]

    benchmark_data = read_benchbase_data(raw_data_file)
    benchmark_data["time_s"] = benchmark_data["start_time_us"] - start_time
    benchmark_data["run_id"] = run_id
    storage.insert("latencies", benchmark_data)


def load_wf_log(storage: Storage, wf_log_file: str, run_id: str) -> None:
    print("Loading WfPatch log")

    def insert(
        table: str,
        data_fn: Callable[[str], pd.DataFrame],
        do_count: Optional[bool] = None,
    ) -> None:
        data = data_fn(wf_log_file)
        data["run_id"] = run_id
        if do_count:
            data["entry_counter"] = range(len(data))
        storage.insert(table, data)

    insert("wf_log_birth", wf_log.read_birth_data)
    insert("wf_log_death", wf_log.read_death_data)
    insert("wf_log_vma", wf_log.read_vma_data, True)
    insert("wf_log_apply", wf_log.read_apply_data, True)
    insert("wf_log_finished", wf_log.read_finished_data, True)
    insert("wf_log_migrated", wf_log.read_migrated_data, True)
    insert("wf_log_reach_quiescence", wf_log.read_reach_quiescence_data, True)
    insert("wf_log_quiescence", wf_log.read_quiescence_data, True)
    insert("wf_log_as_new", wf_log.read_as_new_data, True)
    insert("wf_log_as_delete", wf_log.read_as_delete_data, True)
    insert("wf_log_as_switch", wf_log.read_as_switch_data, True)
    insert("wf_log_patched", wf_log.read_patched_data, True)


def _parse_arguments(input_args: List[str]) -> Namespace:
    parser = ArgumentParser(
        "BEnchmark Data analyzER (BEDER) - a framework to analyze benchmark data based on the data "
        "generated by BenchBase."
    )
    experiment_dir_parser = parser.add_mutually_exclusive_group(required=True)
    experiment_dir_parser.add_argument(
        "--experiment", help="The directory containing the experiment."
    )
    experiment_dir_parser.add_argument(
        "--benchmark", help="The directory containing all the experiment directories."
    )

    parser.add_argument(
        "--success-only",
        help="Read only data for successful benchmark runs",
        action="store_true",
        default=True,
    )
    parser.add_argument(
        "--run-objects-name",
        help="The name of the file containing the objects of the benchmark.",
        default="experiment_objects.yaml",
    )
    parser.add_argument(
        "--wf-log-name", help="The name of the WfPatch log file.", default="wfpatch_log"
    )
    parser.add_argument(
        "--random-run-id",
        help="Use a random run id in case of the same experiment has to be loaded multiple times",
        action="store_true",
        default=USE_RANDOM_RUN_ID,
    )

    parser.add_argument(
        "--output",
        help="The DuckDB database file to which the benchmark data should be added. If the database "
        "file does not exist, a new database file is be created. If the database already exists, "
        "the benchmark data is added.",
        required=True,
        type=str,
    )

    return parser.parse_args(input_args)


def main(input_args: List[str]):
    args = _parse_arguments(input_args)

    global USE_RANDOM_RUN_ID
    USE_RANDOM_RUN_ID = args.random_run_id

    m = multiprocessing.Manager()
    db_input_queue = m.JoinableQueue()

    conn: DuckDBStorage
    storage = DuckDBStorageThread(args.output, db_input_queue)
    conn = storage.connect()
    conn.create_tables()

    collector: Storage = StorageProcessCollector(db_input_queue)

    if args.experiment:
        experiments = [args.experiment]
    else:
        experiments = [
            os.path.join(args.benchmark, experiment)
            for experiment in os.listdir(args.benchmark)
            if os.path.isdir(os.path.join(args.benchmark, experiment))
        ]
    experiments = [os.path.realpath(exp) for exp in experiments]

    pool = FutureCollector(ProcessPoolExecutor(max_workers=15))
    for experiment in experiments:
        pool.submit(
            load_experiment,
            collector,
            experiment,
            args.run_objects_name,
            args.wf_log_name,
            args.success_only,
        )
    pool.shutdown()
    conn.close()


if __name__ == "__main__":
    main(sys.argv[1:])
