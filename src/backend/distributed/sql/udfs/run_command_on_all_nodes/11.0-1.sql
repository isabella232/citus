DROP FUNCTION IF EXISTS pg_catalog.run_command_on_all_nodes;

CREATE FUNCTION pg_catalog.run_command_on_all_nodes(command text, parallel bool default true, OUT nodeid int, OUT success bool, OUT result text)
	RETURNS SETOF record
	LANGUAGE plpgsql
	AS $function$
DECLARE
	nodenames text[];
	ports int[];
	commands text[];
	current_node_is_in_metadata boolean;
	command_result_of_current_node text;
BEGIN
	WITH citus_nodes AS (
		SELECT * FROM pg_dist_node
		WHERE isactive = 't' AND nodecluster = current_setting('citus.cluster_name')
		ORDER BY nodename, nodeport
	)
	SELECT array_agg(citus_nodes.nodename), array_agg(citus_nodes.nodeport), array_agg(command)
	INTO nodenames, ports, commands
	FROM citus_nodes;

	SELECT count(*) > 0 FROM pg_dist_node
	WHERE isactive = 't'
	AND nodecluster = current_setting('citus.cluster_name')
	AND groupid IN (SELECT groupid FROM pg_dist_local_group)
	INTO current_node_is_in_metadata;

	-- This will happen when we call this function on coordinator and
	-- the coordinator is not added to the metadata.
	-- We'll manually add current node to the lists to actually run on all nodes.
	-- But when the coordinator is not added to metadata and this function
	-- is called from a worker node, this will not be enough and we'll
	-- not be able run on all nodes.
	IF NOT current_node_is_in_metadata THEN
		SELECT
		array_append(nodenames, current_setting('citus.local_hostname')),
		array_append(ports, current_setting('port')::int),
		array_append(commands, command)
		INTO nodenames, ports, commands;
	END IF;

	RETURN QUERY
	SELECT coalesce(pg_dist_node.nodeid, 0) AS nodeid, mrow.success, mrow.result
		FROM master_run_on_worker(nodenames, ports, commands, parallel) mrow
		LEFT JOIN pg_dist_node ON mrow.node_name = pg_dist_node.nodename AND mrow.node_port = pg_dist_node.nodeport;
END;
$function$;
