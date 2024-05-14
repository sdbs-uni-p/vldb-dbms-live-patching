import os
import subprocess
from typing import Any, Dict, List, Optional


def taskset_cmd(start: int, end: int, step: int) -> List[str]:
    return ["taskset", "-c", f"{start}-{end}:{step}"]


def timeout_cmd(timeout_min: int) -> List[str]:
    return ["timeout", "-k", "30s", f"{timeout_min}m"]


def datadir_rsync(source: str, destination: str):
    if not source.endswith("/"):
        source = source + "/"
    return ["rsync", "-a", "--delete", f"{source}", f"{destination}"]


def mariadb_cmd(
    bin_dir: str, data_dir: str, threadpool: Optional[int] = None
) -> List[str]:
    cmd = [
        os.path.join(bin_dir, "bin/mysqld"),
        "--no-defaults",
        "--skip-grant-tables",
        f"--datadir={data_dir}",
    ]
    if threadpool is not None:
        cmd += ["--thread-handling=pool-of-threads", f"--thread-pool-size={threadpool}"]
    return cmd


def benchbase_execute_cmd(
    benchmark: str,
    config: str,
    output: str,
    patch_trigger_signal: Optional[str],
    jvm_arguments: Optional[List[str]],
    jvm_heap_size: Optional[int],
    patch_time: Optional[int] = None,
    patch_every: Optional[float] = None,
    skip_latency_recording: Optional[bool] = None,
):
    cmd = ["java"] + (jvm_arguments if jvm_arguments else []) + ["-jar"]
    if jvm_heap_size is not None:
        cmd += [
            f"-Xmx{jvm_heap_size}G",
            f"-Xms{jvm_heap_size}G",
            "-XX:+AlwaysPreTouch",
            "-XX:+UnlockExperimentalVMOptions",
            "-XX:+UseEpsilonGC",
        ]
    cmd += [
        "benchbase.jar",
        "-b",
        benchmark,
        "-c",
        config,
        "--execute=true",
        f"--directory={output}",
    ]

    if patch_trigger_signal:
        cmd += [f"--patch-trigger-signal={patch_trigger_signal}"]
    if skip_latency_recording:
        cmd += ["--skip-latency-recording=true"]

    if patch_time is not None:
        cmd += ["--patch=mysqld", f"--patch-time={patch_time}"]
    if patch_every is not None:
        cmd += ["--patch=mysqld", f"--patch-every={patch_every}"]
    return cmd


def _run_kwargs(
    cwd: str = None,
    env: Dict[str, Any] = None,
    stdout_pipe: Optional[int] = None,
    stderr_pipe: Optional[int] = None,
) -> Dict[str, Any]:
    kwargs = {"cwd": cwd, "stdout": stdout_pipe, "stderr": stderr_pipe}
    if env is not None:
        os_env = os.environ.copy()
        os_env.update({key: str(value) for key, value in env.items()})
        kwargs.update({"env": os_env})
    return kwargs


def run2(
    command: List[str],
    cwd: str = None,
    exception_on_error: bool = True,
    env: Dict[str, Any] = None,
    verbose: bool = False,
) -> subprocess.CompletedProcess:
    return run(
        command,
        cwd,
        exception_on_error,
        env,
        None if verbose else subprocess.DEVNULL,
        None if verbose else subprocess.DEVNULL,
    )


def run(
    command: List[str],
    cwd: str = None,
    exception_on_error: bool = True,
    env: Dict[str, Any] = None,
    stdout_pipe: Optional[int] = None,
    stderr_pipe: Optional[int] = None,
) -> subprocess.CompletedProcess:
    return subprocess.run(
        command,
        check=exception_on_error,
        **_run_kwargs(cwd, env, stdout_pipe, stderr_pipe),
    )


def run2_async(
    command: List[str],
    cwd: str = None,
    env: Dict[str, Any] = None,
    verbose: bool = False,
) -> subprocess.Popen:
    return run_async(
        command,
        cwd,
        env,
        None if verbose else subprocess.DEVNULL,
        None if verbose else subprocess.DEVNULL,
    )


def run_async(
    command: List[str],
    cwd: str = None,
    env: Dict[str, Any] = None,
    stdout_pipe: Optional[int] = None,
    stderr_pipe: Optional[int] = None,
) -> subprocess.Popen:
    return subprocess.Popen(command, **_run_kwargs(cwd, env, stdout_pipe, stderr_pipe))
