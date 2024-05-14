from __future__ import annotations

from abc import ABC
from typing import List, Optional


class _Print(ABC):
    def to_dict(self) -> dict:
        return {
            key: (value.to_dict() if isinstance(value, _Print) else value)
            for key, value in vars(self).items()
        }

    def __str__(self):
        attributes = "\n\t".join(
            f"{attr}: {getattr(self, attr)}" for attr in vars(self)
        )
        return f"{type(self).__name__}\n\t{attributes}"


class Experiment(_Print):
    def __init__(
        self,
        name: str,
        build: Build,
        data: Data,
        benchmark: Benchmark,
        database: Database,
        benchbase: BenchBase,
        patch: Patch,
    ):
        # Input
        self.name: str = name
        self.build: Build = build
        self.data: Data = data
        self.benchmark: Benchmark = benchmark
        self.database: Database = database
        self.benchbase = benchbase
        self.patch: Patch = patch

        # Output
        self.commit: str = None
        self.success: bool = None
        self.db_failure: bool = None
        self.benchmark_failure: bool = None
        self.benchmark_timeout: bool = None


class Build(_Print):
    def __init__(self):
        # Input
        self.dir: str = None
        self.git_dir_name: str = None
        self.output: str = None

        # Output
        self.bin_dir: str = None
        self.patches: List[str] = None


class Data(_Print):
    def __init__(self):
        # Input
        self.output: str = None


class Benchmark(_Print):
    def __init__(self):
        # Input
        self.output_name: str = None
        self.name: str = None
        self.config: str = None
        self.dir: str = None
        self.output: str = None
        self.taskset_start: int = None
        self.taskset_end: int = None
        self.taskset_step: int = None
        self.kill_min: int = None


class Database(_Print):
    def __init__(self):
        # Input
        self.threadpool_size: Optional[int] = None
        self.taskset_start: int = None
        self.taskset_end: int = None
        self.taskset_step: int = None
        self.flags: List[str] = None


class BenchBase(_Print):
    def __init__(self):
        # Input
        self.jvm_heap_size: Optional[int] = None
        self.jvm_arguments: List[str] = None
        self.trigger_signal: Optional[str] = None
        self.skip_latency_recording: Optional[bool] = None


class Patch(_Print):
    def __init__(self):
        # Input
        self.global_quiescence: bool = None
        self.patch_group: Optional[str] = None
        self.measure_vma: bool = None
        self.patch_only_active: bool = None
        self.apply_all_patches_at_once: bool = None
        self.single_as_for_each_thread: bool = None
        self.logfile_name: str = None
        self.skip_patch_file: bool = None
        self.time: Optional[int] = None
        self.every: Optional[float] = None
