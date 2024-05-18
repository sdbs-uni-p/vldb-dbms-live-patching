CREATE TABLE IF NOT EXISTS run (
    -- Run
    run_id VARCHAR PRIMARY KEY,
    run_success BOOLEAN,
    run_db_failure BOOLEAN,
    run_benchmark_failure BOOLEAN,
    run_benchmark_timeout BOOLEAN,
    -- Experiment
    experiment_name VARCHAR,
    experiment_commit VARCHAR,
    -- Database attributes
    db_taskset_start INTEGER,
    db_taskset_end INTEGER,
    db_taskset_step INTEGER,
    db_threadpool_size INTEGER,
    db_flags VARCHAR,
    -- Benchmark attributes
    benchmark_name VARCHAR,
    benchmark_output_name VARCHAR,
    benchmark_taskset_start INTEGER,
    benchmark_taskset_end INTEGER,
    benchmark_taskset_step INTEGER,
    benchmark_trigger_signal VARCHAR,
    benchmark_jvm_heap_size INTEGER,
    benchmark_jvm_arguments VARCHAR,
    benchmark_kill_min INTEGER,
    -- Patch attributes
    patch_global_quiescence BOOLEAN,
    patch_group VARCHAR,
    patch_skip_patch_file BOOLEAN,
    patch_apply_all_patches_at_once BOOLEAN,
    patch_measure_vma BOOLEAN,
    patch_patch_only_active BOOLEAN,
    patch_single_as_for_each_thread BOOLEAN,
    patch_time_s INTEGER,
    patch_every_s DOUBLE,
);

CREATE TABLE IF NOT EXISTS benchmark (
    -- BenchBase config
    benchmark_scalefactor INTEGER,
    benchmark_terminals INTEGER,
    benchmark_warmup_s INTEGER,
    benchmark_duration_s INTEGER,
    benchmark_rate VARCHAR,
    -- BenchBase patch.csv file
    benchmark_log_start_time DOUBLE,
    benchmark_log_end_time DOUBLE,
    benchmark_log_duration_s DOUBLE,
    benchmark_log_patch_time DOUBLE,
    benchmark_log_patch_time_s DOUBLE,
    -- References
    run_id VARCHAR -- REFERENCES run(run_id)
);

CREATE TABLE IF NOT EXISTS benchmark_log_warmup (
    worker_id INTEGER,
    start_time_us DOUBLE,
    latency_us DOUBLE,
    -- Own
    time_s DOUBLE,
    -- Reference
    run_id VARCHAR -- REFERENCES run(run_id)
);

CREATE TABLE IF NOT EXISTS benchmark_log_done (
    worker_id INTEGER,
    start_time_us DOUBLE,
    latency_us DOUBLE,
    -- OWN
    time_s DOUBLE,
    -- Reference
    run_id VARCHAR -- REFERENCES run(run_id)
);

CREATE TABLE IF NOT EXISTS latencies (
  -- from benchmark framework
  transaction_type INTEGER,
  transaction_name VARCHAR,
  start_time_us DOUBLE,
  latency_us DOUBLE,
  worker_id INTEGER,
  phase_id INTEGER,
  -- Own
  time_s DOUBLE,
  -- References
  run_id VARCHAR -- REFERENCES run(run_id)
);

CREATE TABLE IF NOT EXISTS patch_file (
    name VARCHAR,
    size_bytes INTEGER,
    -- References
    run_id VARCHAR -- REFERENCES run(run_id)
);

CREATE TABLE IF NOT EXISTS patch_elf (
    file_name VARCHAR,
    section_name VARCHAR,
    size_bytes INTEGER,
    type VARCHAR,
    -- Reference
    run_id VARCHAR -- REFERENCES run(run_id)
);

CREATE TABLE IF NOT EXISTS wf_log_birth (
    name VARCHAR,
    time DOUBLE,
    thread_name VARCHAR,
    thread_group_name VARCHAR,
    thread_id INTEGER,
    -- References
    run_id VARCHAR -- REFERENCES run(run_id)
);

CREATE TABLE IF NOT EXISTS wf_log_death (
    name VARCHAR,
    duration_ms DOUBLE,
    thread_name VARCHAR,
    thread_group_name VARCHAR,
    thread_id INTEGER,
    -- References
    run_id VARCHAR -- REFERENCES run(run_id)
);

CREATE TABLE IF NOT EXISTS wf_log_apply (
    name VARCHAR,
    time DOUBLE,
    quiescence VARCHAR,
    amount_threads INTEGER,
    thread_group_name VARCHAR,
    entry_counter INTEGER,
    -- References
    run_id VARCHAR -- REFERENCES run(run_id)
);

CREATE TABLE IF NOT EXISTS wf_log_finished (
    name VARCHAR,
    duration_ms DOUBLE,
    thread_group_name VARCHAR,
    entry_counter INTEGER,
    -- References
    run_id VARCHAR -- REFERENCES run(run_id)
);

CREATE TABLE IF NOT EXISTS wf_log_migrated (
    name VARCHAR,
    duration_ms DOUBLE,
    current_address_space_version INTEGER,
    thread_name VARCHAR,
    thread_group_name VARCHAR,
    thread_id INTEGER,
    entry_counter INTEGER,
    -- References
    run_id VARCHAR -- REFERENCES run(run_id)
);

CREATE TABLE IF NOT EXISTS wf_log_quiescence (
    name VARCHAR,
    duration_ms DOUBLE,
    thread_group_name VARCHAR,
    entry_counter INTEGER,
    -- References
    run_id VARCHAR -- REFERENCES run(run_id)
);


CREATE TABLE IF NOT EXISTS wf_log_reach_quiescence (
    name VARCHAR,
    duration_ms DOUBLE,
    thread_name VARCHAR,
    thread_group_name VARCHAR,
    thread_id INTEGER,
    entry_counter INTEGER,
    -- References
    run_id VARCHAR -- REFERENCES run(run_id)
);

CREATE TABLE IF NOT EXISTS wf_log_as_new (
    name VARCHAR,
    duration_ms DOUBLE,
    thread_group_name VARCHAR,
    entry_counter INTEGER,
    -- References
    run_id VARCHAR -- REFERENCES run(run_id)
);

CREATE TABLE IF NOT EXISTS wf_log_as_delete (
    name VARCHAR,
    duration_ms DOUBLE,
    thread_group_name VARCHAR,
    entry_counter INTEGER,
    -- References
    run_id VARCHAR -- REFERENCES run(run_id)
);

CREATE TABLE IF NOT EXISTS wf_log_as_switch (
    name VARCHAR,
    duration_ms DOUBLE,
    entry_counter INTEGER,
    -- References
    run_id VARCHAR -- REFERENCES run(run_id)
);

CREATE TABLE IF NOT EXISTS wf_log_patched (
    name VARCHAR,
    duration_ms DOUBLE,
    entry_counter INTEGER,
    -- References
    run_id VARCHAR -- REFERENCES run(run_id)
);


CREATE TABLE IF NOT EXISTS wf_log_vma (
    name VARCHAR,
    wfpatch_generation INTEGER,
    perm VARCHAR,
    type VARCHAR,
    count INTEGER,
    size INTEGER,
    shared_clean INTEGER,
    shared_dirty INTEGER,
    private_clean INTEGER,
    private_dirty INTEGER,
    entry_counter INTEGER,
    -- References
    run_id VARCHAR -- REFERENCES run(run_id)
);

