#!/usr/bin/env python3

import csv
import mariadb
import subprocess
import multiprocessing
import time
import os

DIR = os.path.dirname(os.path.realpath(__file__))
OUTPUT_FILE = "result/patch_one_by_one_raw.csv"
WF_OUTPUT_FILE = "result/patch_one_by_one_wf.csv"
DB_WF_OUTPUT_FILE = "result/wf_log.txt"

def connect():
    return mariadb.connect(user="root", host="127.0.0.1", port=3306)

def start_db():
    patches = [os.path.join(DIR, "patches", str(i), "patch--sql_parse.cc.o") for i in range(1, 11)]
    env = {"WF_PATCH_TRIGGER_FIFO": "/tmp/mariadb-trigger-patch", "WF_GLOBAL": "0", "WF_PATCH_QUEUE": ';'.join(patches), "WF_LOGFILE": os.path.join(DIR, DB_WF_OUTPUT_FILE)}
    cmd = ["./bin/bin/mysqld", "--no-defaults", "--skip-grant-tables", f"--datadir={os.path.join(DIR, 'patches', 'db')}", "--thread_cache_size=0"]
    db_proc = subprocess.Popen(cmd, cwd = os.path.join(DIR, "patches", "1"), env=env)#, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return db_proc

def stop_db(pid: int):
    os.system(f"kill -15 {pid}")

def run(start_event, end_event, queue, worker_id):
    start_event.wait()
    if end_event.is_set():
        return

    conn = connect()
    cursor = conn.cursor()
    
    latencies = []
    while not end_event.is_set():
        start = time.time()
        cursor.execute("SELECT 0")
        end = time.time()
        for res in cursor:
            # end - start is in seconds; transform it to ms
            latencies.append((start, end, (end - start) * 1000., res[0], worker_id))
        qps = 5
        time.sleep(1.0/qps)
    
    queue.put(latencies)

    cursor.close()
    conn.close()

    queue.close()

def patcher(delay: int, phases: int, start_event: multiprocessing.Event, scale_event: multiprocessing.Event):
    start_event.wait()
    for _ in range(phases):
        time.sleep(delay)
        patch()
        print("---" * 10)
        print("NEW VERSION")
        print("---" * 10)
        scale_event.set()
    # This finishes the scaler
    time.sleep(delay)
    scale_event.set()
    
def patch():
    with open("/tmp/mariadb-trigger-patch", "w") as f:
        f.write("1")

def main():
    db_proc = start_db()
    time.sleep(3)

    delay_between_versions = 5 #seconds
    workers = [1, 3, 5, 1]
    
    # Prepare all threads
    worker_processes = []
    for i in range(sum(workers)):
        start_event = multiprocessing.Event()
        end_event = multiprocessing.Event()
        queue = multiprocessing.Queue()
        proc = multiprocessing.Process(target=run, args=(start_event, end_event, queue, i, ))
        proc.start() # Start process to not have any delay during run
        worker_processes.append((proc, start_event, end_event, queue, i))
    
    scale_event = multiprocessing.Event()
    start_patcher_event = multiprocessing.Event()
    
    patcher_proc = multiprocessing.Process(target=patcher, args=(delay_between_versions, len(workers) - 1, start_patcher_event, scale_event, ))
    patcher_proc.start() # Start process to not have any delay during run

    current_worker_processes = []
    finished_worker_processes = []
    for idx, amount_workers in enumerate(workers):
        # Too few workers
        while len(current_worker_processes) < amount_workers:
            print("+++ CONN.")
            current_worker_processes.append(worker_processes.pop(0))
            current_worker_processes[-1][1].set() # Set start event

        # Too many connections
        while len(current_worker_processes) > amount_workers:
            print("--- CONN.")
            finished_worker_processes.append(current_worker_processes.pop())
            finished_worker_processes[-1][2].set() # Set end event

        if idx == 0:
            # In first iteration, start the patcher thread
            time.sleep(0.4) # Some delay to wait for first query..
            start_patcher_event.set()

        scale_event.wait()
        scale_event.clear()
    
    print("Shutdown all processes..!")
    # Shutdown all processes
    for _, start_event, end_event, *_ in worker_processes + current_worker_processes + finished_worker_processes:
        end_event.set()
        start_event.set() # In case worker has not started yet
    finished_worker_processes.extend(current_worker_processes)

    time.sleep(1)
    stop_db(db_proc.pid)    
    time.sleep(1)

    data = []
    while len(finished_worker_processes) > 0:
        proc, start_event, end_event, queue, worker_id = finished_worker_processes[0]
        while not queue.empty():
            # Queue is too full, so proc may not exit due to the queue. 
            # 1. clear queue
            data.extend(queue.get())
        # 2. Check if proc is killed now. If not, try to clear queue again..
        if proc.is_alive():
            continue
        # Remove element
        del finished_worker_processes[0]
    
    with open(OUTPUT_FILE, "w") as f:
        csv_writer = csv.writer(f)
        csv_writer.writerow(["start", "end", "latency_ms", "version", "worker"])
        csv_writer.writerows(data)
    
    print(f"Wrote {len(data)} lines")
    with open(DB_WF_OUTPUT_FILE) as f:
        lines = f.readlines()

    def extract_second_element_from_wflog(key: str):
        return [float(line.split(",")[1].strip()) for line in lines if line.startswith(key)]

    apply_lines = extract_second_element_from_wflog("- [apply,")
    patched_lines = extract_second_element_from_wflog("- [patched,")
    
    with open(WF_OUTPUT_FILE, "w") as f:
        csv_writer = csv.writer(f)
        csv_writer.writerow(["start", "latency_ms"])
        for apply_time, latency_ms in zip(apply_lines, patched_lines):
            csv_writer.writerow([apply_time, latency_ms])
    print("Wrote patch file")


if __name__ == "__main__":
	main()
