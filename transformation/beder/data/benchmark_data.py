import pandas as pd


def read_benchbase_data(file: str) -> pd.DataFrame:
    return read_laser_bench_data(file)


def read_laser_bench_data(file: str) -> pd.DataFrame:
    # Header of LaSeR-Bench:
    # Transaction Type Index,Transaction Name,Start Time (microseconds),Latency (microseconds),Worker Id (start number),Phase Id (index in config file)  # noqa: E501
    df = pd.read_csv(file)
    df.columns = [
        "transaction_type",
        "transaction_name",
        "start_time_us",
        "latency_us",
        "worker_id",
        "phase_id",
    ]
    df["time_s"] = None

    if len(df[df["latency_us"] < 0]) > 0:
        print(df)
        print("DataFrame contains negative latency. Maybe a overflow happened?")
        exit(1)

    return df
