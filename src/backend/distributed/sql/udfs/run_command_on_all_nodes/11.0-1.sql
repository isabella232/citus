DROP FUNCTION IF EXISTS pg_catalog.run_command_on_all_nodes;

CREATE FUNCTION pg_catalog.run_command_on_all_nodes(command text, parallel bool default true, OUT nodeid int, OUT success bool, OUT result text)
	RETURNS SETOF record
	LANGUAGE plpgsql
	AS $function$
DECLARE
	nodenames text[];
	ports int[];
	commands text[];
BEGIN
	WITH citus_nodes AS (
		SELECT * FROM pg_dist_node
		WHERE isactive = 't' AND nodecluster = current_setting('citus.cluster_name')
		ORDER BY nodename, nodeport
	)
	SELECT array_agg(citus_nodes.nodename), array_agg(citus_nodes.nodeport), array_agg(command)
	INTO nodenames, ports, commands
	FROM citus_nodes;

	RETURN QUERY SELECT pg_dist_node.nodeid, mrow.success, mrow.result FROM
	master_run_on_worker(nodenames, ports, commands, parallel) mrow
	JOIN pg_dist_node ON mrow.node_name = pg_dist_node.nodename AND mrow.node_port = pg_dist_node.nodeport;
END;
$function$;
