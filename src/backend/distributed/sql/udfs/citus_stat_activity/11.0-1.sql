DROP VIEW IF EXISTS pg_catalog.citus_stat_activity;
DROP TYPE IF EXISTS pg_catalog.citus_stat_activity_one_node;

CREATE TYPE citus.citus_stat_activity_one_node AS (global_pid bigint, worker_query boolean, pg_stat_activity pg_stat_activity);

ALTER TYPE citus.citus_stat_activity_one_node SET SCHEMA pg_catalog;
GRANT ALL ON TYPE pg_catalog.citus_stat_activity_one_node TO PUBLIC;

CREATE VIEW citus.citus_stat_activity AS
SELECT all_csa_1n.global_pid, nodeid, all_csa_1n.worker_query, (all_csa_1n.pg_stat_activity).*
FROM (
    SELECT * FROM run_command_on_all_nodes($$
        SELECT coalesce(to_json(array_agg(csa_1n.*)), '[{}]'::JSON)
        FROM (
            SELECT global_pid, worker_query, (pg_stat_activity.*)::pg_stat_activity FROM
            pg_stat_activity LEFT JOIN get_all_active_transactions() ON process_id = pid
        ) AS csa_1n;
    $$)
    WHERE success = 't'
) AS run_command_on_all_nodes
LEFT JOIN LATERAL json_populate_recordset(NULL::citus_stat_activity_one_node, run_command_on_all_nodes.result::JSON) as all_csa_1n ON TRUE;

ALTER VIEW citus.citus_stat_activity SET SCHEMA pg_catalog;
GRANT SELECT ON pg_catalog.citus_stat_activity TO PUBLIC;
