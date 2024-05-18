from typing import Any

import pandas as pd
import xmltodict


def read_benchbase_benchmark_data(patch_file: str, config_file: str) -> pd.DataFrame:
    patch_df, *_ = _read_patch_data(patch_file)
    config_df = _read_config_data(config_file)
    return patch_df.join(config_df)


def read_benchbase_warmup_done_data(patch_file: str) -> pd.DataFrame:
    _, warmup_df, done_df = _read_patch_data(patch_file)
    return warmup_df, done_df


def _read_config_data(file: str) -> pd.DataFrame:
    # {'configuration': {'isolation': 'TRANSACTION_SERIALIZABLE', 'batchsize': '128', 'scalefactor': '10', 'terminals': '10', 'works': {'work': {'warmup': '75', 'time': '300', 'rate': 'unlimited', 'weights': {'@bench': 'chbenchmark', '#text': '3, 2, 3, 2, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5'}}}, 'transactiontypes': {'@bench': 'chbenchmark', 'transactiontype': [{'name': 'Q1'}, {'name': 'Q2'}, {'name': 'Q3'}, {'name': 'Q4'}, {'name': 'Q5'}, {'name': 'Q6'}, {'name': 'Q7'}, {'name': 'Q8'}, {'name': 'Q9'}, {'name': 'Q10'}, {'name': 'Q11'}, {'name': 'Q12'}, {'name': 'Q13'}, {'name': 'Q14'}, {'name': 'Q15'}, {'name': 'Q16'}, {'name': 'Q17'}, {'name': 'Q18'}, {'name': 'Q19'}, {'name': 'Q20'}, {'name': 'Q21'}, {'name': 'Q22'}]}}} # noqa: E501
    with open(file) as f:
        config = xmltodict.parse(f.read())["configuration"]

    def get_work_data(key: str, default: Any = None, try_default: bool = False) -> Any:
        if try_default:
            return config["works"]["work"].get(key, default)
        return config["works"]["work"][key]

    warmup = get_work_data("warmup", None, True)
    return pd.DataFrame(
        data={
            "benchmark_scalefactor": [int(config["scalefactor"])],
            "benchmark_terminals": [int(config["terminals"])],
            "benchmark_warmup_s": [warmup if warmup is None else int(warmup)],
            "benchmark_duration_s": [int(get_work_data("time"))],
            "benchmark_rate": [get_work_data("rate")],
        }
    )


def _read_patch_data(file: str) -> pd.DataFrame:
    # Patch Application,Start Time (microseconds),Latency (microseconds)
    # <START>,1672942977.298716,0
    # mysqld,1672943002.298406,6073
    # <WARMUP> 0,1675279390.979683,1994074789
    # <END>,1672943277.298559,0
    # <DONE> 8,1675281514.830610,876899789

    df = pd.read_csv(file)
    df.columns = [
        "application",
        "time",
        "latency_us",
    ]

    start_time = df[df["application"] == "<START>"].iloc[0].time
    end_time = df[df["application"] == "<END>"].iloc[-1].time
    patch_df = df[
        ~df["application"].isin(["<START>", "<END>"])
        & ~df["application"].str.startswith("<WARMUP>")
        & ~df["application"].str.startswith("<WARMUP-DONE")
        & ~df["application"].str.startswith("<DONE>")
    ].copy(deep=True)

    def fix_latency_overflow(df: pd.DataFrame, column: str):
        # BenchBase uses int for latencies. Latencies are given in microseconds
        # Java int range: -2147483648 to 2147483647
        # 2147483647 are about 35 Minutes.
        # For ch-benchmark, it may be the case that we exceed 35 Minutes
        df.loc[df[column] < 0, [column]] = (
            df[df[column] < 0][column] - -2147483648 + 1 + 2147483647
        )

    def extract_warmup_done_latencies(application: str):
        app_df = df[df["application"].str.startswith(application)]
        fix_latency_overflow(app_df, "latency_us")
        return pd.DataFrame(
            data={
                "worker_id": app_df["application"].map(lambda x: int(x.split(" ")[1])),
                "start_time_us": app_df["time"],
                "latency_us": app_df["latency_us"],
                "time_s": app_df["time"] - start_time,
            }
        )

    warmup_df = extract_warmup_done_latencies("<WARMUP>")
    done_df = pd.concat(
        [
            extract_warmup_done_latencies("<DONE>"),
            extract_warmup_done_latencies("<WARMUP-DONE>"),
        ]
    )

    patch_df["time_s"] = patch_df["time"] - start_time

    patch_size = 1 if len(patch_df) == 0 else len(patch_df)
    return (
        pd.DataFrame(
            data={
                "benchmark_log_start_time": [start_time] * patch_size,
                "benchmark_log_end_time": [end_time] * patch_size,
                "benchmark_log_duration_s": [end_time - start_time] * patch_size,
                "benchmark_log_patch_time": (
                    patch_df["time"] if len(patch_df) > 0 else [None]
                ),
                "benchmark_log_patch_time_s": (
                    patch_df["time_s"] if len(patch_df) > 0 else [None]
                ),
            }
        ),
        warmup_df,
        done_df,
    )
