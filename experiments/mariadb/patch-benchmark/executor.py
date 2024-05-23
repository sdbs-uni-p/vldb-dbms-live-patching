import datetime
import os
import shutil
import sys
import time
from argparse import ArgumentParser, Namespace
from copy import deepcopy
from typing import Any, List

import process
import yaml
from config import parse_config
from model import Experiment

VERBOSE = False

log_buffer: List[str] = []


def log(msg: Any):
    msg = f"{datetime.datetime.now().isoformat()} {msg}"
    print(msg)
    log_buffer.append(msg)


def write_log(file: str):
    with open(file, "a") as f:
        f.write("\n".join(log_buffer))
        f.write("\n")
    log_buffer.clear()


def touch(path):
    with open(path, "a"):
        os.utime(path, None)


def get_path_from_root(paths: List[str]) -> str:
    return os.path.realpath(
        os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", *paths)
    )


def get_script(name: str) -> str:
    return os.path.realpath(
        os.path.join(os.path.dirname(os.path.realpath(__file__)), "scripts", name)
    )


def build(experiment: Experiment) -> None:
    command = [
        get_path_from_root(["mariadb-wfpatch-utils", "build"]),
        "--commit",
        experiment.commit,
        "--build-dir",
        experiment.build.dir,
        "--git-name",
        experiment.build.git_dir_name,
        "--output-dir",
        experiment.build.output,
    ]

    log(f"[BUILD] {command}")
    process.run2(command, verbose=VERBOSE)
    experiment.build.bin_dir = os.path.join(experiment.build.output, "bin")


def create_patches(experiment: Experiment) -> None:
    command = [
        get_path_from_root(["mariadb-wfpatch-utils", "generate-patch"]),
        "--dir",
        experiment.build.output,
    ]

    log(f"[CREATE PATCH] {command}")
    process.run2(command, verbose=VERBOSE)

    experiment.build.patches = (
        []
        if experiment.patch.skip_patch_file
        else [
            os.path.join(experiment.build.output, file)
            for file in os.listdir(experiment.build.output)
            if file.startswith("patch--")
        ]
    )


def create_db_data(experiment: Experiment) -> bool:
    if os.path.isdir(experiment.data.output):
        # Already exists, nothing to do
        return False

    # Directory must exists to initialize a db data directory
    os.makedirs(experiment.data.output, exist_ok=True)

    command = [
        os.path.join(experiment.build.bin_dir, "scripts/mysql_install_db"),
        f"--datadir={experiment.data.output}",
    ]

    log(f"[CREATE DB DATA] {command}")
    process.run2(command, verbose=VERBOSE)
    return True


def fill_db_data(experiment: Experiment) -> None:
    env = {
        "DB_BIN_DIR": experiment.build.bin_dir,
        "DB_DATA_DIR": experiment.data.output,
        "BENCHBASE_DIR": experiment.benchmark.dir,
        "BENCHMARK": experiment.benchmark.name,
        "BENCHMARK_CONFIG": experiment.benchmark.config,
    }
    command = [get_script("load_data")]

    log(f"[FILL DB DATA] {command} with env {env}")
    process.run2(command, env=env, verbose=VERBOSE)


def benchmark(experiment: Experiment) -> None:
    # Prepare system for benchmark
    prepare_benchmark_command = [get_script("prepare_benchmark")]
    log(f"[BENCHMARK - Prepare] {prepare_benchmark_command}")
    process.run2(prepare_benchmark_command, verbose=VERBOSE, exception_on_error=False)

    # Put datadir into /tmp (RAM)
    data_dir = "/tmp/mariadb-db-datadir"
    rsync_datadir_command = process.datadir_rsync(experiment.data.output, data_dir)
    log(f"[BENCHMARK - RSYNC] {rsync_datadir_command}")
    process.run2(rsync_datadir_command, verbose=VERBOSE)

    # Get next free index for a result directory
    specific_experiment_dir_counter = 0
    if os.path.exists(experiment.benchmark.output):
        while True:
            if any(
                file.startswith(str(specific_experiment_dir_counter))
                for file in os.listdir(experiment.benchmark.output)
            ):
                specific_experiment_dir_counter += 1
            else:
                break

    experiment_specific_benchmark_result_dir = os.path.join(
        experiment.benchmark.output,
        (
            f"{specific_experiment_dir_counter}"
            f"-{experiment.patch.time if experiment.patch.time is not None else experiment.patch.every}"
            f"-{int(experiment.patch.global_quiescence)}"
            f"-{experiment.database.threadpool_size}"
        ),
    )

    mariadb_command = (
        process.taskset_cmd(
            experiment.database.taskset_start,
            experiment.database.taskset_end,
            experiment.database.taskset_step,
        )
        + process.mariadb_cmd(
            experiment.build.bin_dir,
            data_dir,
            threadpool=experiment.database.threadpool_size,
        )
        + (experiment.database.flags if experiment.database.flags else [])
    )
    benchmark_command = (
        process.timeout_cmd(
            experiment.benchmark.kill_min,
        )
        + process.taskset_cmd(
            experiment.benchmark.taskset_start,
            experiment.benchmark.taskset_end,
            experiment.benchmark.taskset_step,
        )
        + process.benchbase_execute_cmd(
            experiment.benchmark.name,
            experiment.benchmark.config,
            experiment_specific_benchmark_result_dir,
            experiment.benchbase.trigger_signal,
            experiment.benchbase.jvm_arguments,
            experiment.benchbase.jvm_heap_size,
            patch_time=experiment.patch.time,
            patch_every=experiment.patch.every,
            skip_latency_recording=experiment.benchbase.skip_latency_recording,
        )
    )

    env = {
        "WF_PATCH_TRIGGER_FIFO": "/tmp/mariadb-trigger-patch",
        "WF_GLOBAL": int(experiment.patch.global_quiescence),
        "WF_PATCH_QUEUE": (
            "," if experiment.patch.apply_all_patches_at_once else ";"
        ).join(experiment.build.patches),
        "WF_LOGFILE": os.path.join(
            experiment_specific_benchmark_result_dir, experiment.patch.logfile_name
        ),
        "WF_MEASURE_VMA": int(experiment.patch.measure_vma),
        "WF_LOCAL_SINGLE_AS": int(experiment.patch.single_as_for_each_thread),
        "WF_PATCH_ONLY_ACTIVE": int(experiment.patch.patch_only_active),
    }
    if experiment.patch.patch_group is not None:
        env["WF_GROUP"] = experiment.patch.patch_group

    os.makedirs(experiment_specific_benchmark_result_dir, exist_ok=True)
    touch(env["WF_LOGFILE"])

    # Execute Benchmark
    # Start MariaDB
    log(f"[BENCHMARK - MariaDB Command] {mariadb_command} with env {env}")
    mariadb_log_file = open(
        os.path.join(experiment_specific_benchmark_result_dir, "database_log"), "w"
    )
    mariadb_proc = process.run_async(
        mariadb_command,
        env=env,
        stdout_pipe=mariadb_log_file,
        stderr_pipe=mariadb_log_file,
    )

    log("Sleeping.. Waiting for MariaDB to start..")
    time.sleep(5)

    # Start Benchmark
    log(f"[BENCHMARK - Benchmark Command] {benchmark_command}")
    benchmark_log_file = open(
        os.path.join(experiment_specific_benchmark_result_dir, "benchmark_log"), "w"
    )
    benchmark_proc = process.run(
        benchmark_command,
        exception_on_error=False,
        cwd=experiment.benchmark.dir,
        stdout_pipe=benchmark_log_file,
        stderr_pipe=benchmark_log_file,
    )
    benchmark_log_file.close()

    experiment.success = False
    experiment.db_failure = False
    experiment.benchmark_failure = False
    experiment.benchmark_timeout = False

    result: str
    if benchmark_proc.returncode == 0:
        if mariadb_proc.poll() is None:
            # Good :-). MariaDB still alive
            result = "SUCCESS"
            experiment.success = True
        else:
            # MariaDB shut down
            result = "DB_FAILURE"
            experiment.db_failure = True

    else:
        if benchmark_proc.returncode == 124:
            result = "BENCHMARK_TIMEOUT"
            experiment.benchmark_timeout = True
        else:
            result = "BENCHMARK_FAILURE"
            experiment.benchmark_failure = True

    # Store benchmark result
    touch(os.path.join(experiment_specific_benchmark_result_dir, result))

    # Store experiment object
    with open(
        os.path.join(
            experiment_specific_benchmark_result_dir, "experiment_objects.yaml"
        ),
        "w",
    ) as f:
        yaml.dump(experiment.to_dict(), f, sort_keys=False)

    if mariadb_proc.poll() is None:
        mariadb_proc.terminate()
        time.sleep(5)
        mariadb_proc.kill()
    mariadb_log_file.close()

    teardown_benchmark_command = [get_script("teardown_benchmark")]
    log(f"[BENCHMARK - Teardown] {teardown_benchmark_command}")
    process.run2(teardown_benchmark_command, verbose=VERBOSE, exception_on_error=False)


def store_metadata(experiment: Experiment) -> None:
    output = experiment.benchmark.output

    # Copy all patches
    for patch in experiment.build.patches:
        shutil.copy2(patch, os.path.join(output, os.path.basename(patch)))
    shutil.copy2(
        os.path.join(experiment.build.output, "patch.patch"),
        os.path.join(output, "patch.patch"),
    )


def notify(message: str) -> None:
    command = [get_script("notify"), message]

    log(f"[NOTIFY] {command}")
    process.run2(command, verbose=VERBOSE, exception_on_error=False)


def execute(experiment: Experiment, load_only: bool = False) -> None:
    # Steps:
    # 1. Build Project
    build(experiment)
    # 2. Create Patches
    create_patches(experiment)
    # 3. Create DB directory
    new_db_data_dir = create_db_data(experiment)
    # 4. Fill DB with data
    if new_db_data_dir:
        fill_db_data(experiment)
    if load_only:
        return
    # 5. Execute Experiment
    benchmark(experiment)
    # 6. Store some meta data
    store_metadata(experiment)

    write_log(os.path.join(experiment.benchmark.output, "log"))


def parse_args(input_args: List[str]) -> Namespace:
    parser = ArgumentParser()
    parser.add_argument("-v", "--verbose", help="Verbose output", action="store_true")
    parser.add_argument(
        "--load-only", help="Create DB data dir only", action="store_true"
    )
    parser.add_argument(
        "--dry-run", help="Dry-Run. Do not perform any action.", action="store_true"
    )
    parser.add_argument(
        "--commits", help="The list containing the commits", required=True
    )
    parser.add_argument("--config", help="The configuration file", required=True)
    parser.add_argument(
        "--overwrite",
        help="Allows to overwrite settings ot the configuration file. Format: path=value. "
        "Example: build.output='new-output'",
        nargs="+",
        required=False,
    )
    return parser.parse_args(input_args)


def main(input_args: List[str]) -> None:
    args = parse_args(input_args)

    global VERBOSE
    VERBOSE = args.verbose

    configured_experiments: List[Experiment] = parse_config(args.config, args.overwrite)
    with open(args.commits) as f:
        commits = [line.strip() for line in f.readlines() if line.strip()]

    print(
        f"{len(configured_experiments)} experiments configured. {len(commits)} commits given."
    )

    def create_experiment(commit: str, experiment: Experiment) -> Experiment:
        experiment_with_commit = deepcopy(experiment)
        experiment_with_commit.commit = commit
        return experiment_with_commit

    experiments: List[Experiment] = [
        create_experiment(commit, experiment)
        for commit in commits
        for experiment in configured_experiments
    ]
    print(f"In total {len(experiments)} experiments will be executed.")

    def prepare_experiment_directories(experiment: Experiment) -> None:
        experiment.build.output = os.path.join(
            experiment.build.output, experiment.commit
        )
        experiment.data.output = os.path.join(
            experiment.data.output,
            f"{experiment.commit}-{experiment.benchmark.output_name}",
        )
        experiment.benchmark.output = os.path.join(
            experiment.benchmark.output,
            f"{experiment.commit}-{experiment.benchmark.output_name}",
        )

    counter = 1
    for experiment in experiments:
        prepare_experiment_directories(experiment)
        log(yaml.safe_dump(experiment.to_dict(), sort_keys=False))
        log(f"Executing experiment {counter}/{len(experiments)}")
        if not args.dry_run:
            notify(
                f"START {counter}/{len(experiments)} {experiment.benchmark.name} {experiment.benchmark.output_name} {experiment.commit}"  # noqa: E501
            )
            try:
                execute(experiment, args.load_only)
            except Exception as e:
                notify(
                    f"ERROR ERROR ERROR {counter}/{len(experiments)} {experiment.benchmark.name} {experiment.benchmark.output_name} {experiment.commit}"  # noqa: E501
                )
                raise e
            notify(
                f"END {counter}/{len(experiments)} {experiment.benchmark.name} {experiment.benchmark.output_name} {experiment.commit}"  # noqa: E501
            )
        counter += 1


if __name__ == "__main__":
    main(sys.argv[1:])
