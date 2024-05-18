CREATE TABLE IF NOT EXISTS run (
    -- Run
    run_id VARCHAR PRIMARY KEY,
    global_patch_time_ms DOUBLE,
    local_patch_time_ms DOUBLE,
);

CREATE TABLE IF NOT EXISTS patch_elf (
    file_name VARCHAR,
    section_name VARCHAR,
    size_bytes INTEGER,
    type VARCHAR,
    -- Reference
    run_id VARCHAR REFERENCES run(run_id)
);

