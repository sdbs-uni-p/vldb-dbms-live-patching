SELECT MIN(duration_ms), MAX(duration_ms)
FROM (
SELECT m.duration_ms - q.duration_ms as duration_ms
FROM wf_log_reach_quiescence q JOIN wf_log_migrated m USING(run_id, thread_id, entry_counter)
);
