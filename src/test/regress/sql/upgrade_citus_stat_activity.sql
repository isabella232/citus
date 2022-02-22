SELECT column_name FROM information_schema.columns WHERE table_name = 'citus_stat_activity'
EXCEPT SELECT column_name FROM information_schema.columns WHERE table_name = 'pg_stat_activity'
ORDER BY 1;

SELECT column_name FROM information_schema.columns WHERE table_name = 'pg_stat_activity'
EXCEPT SELECT column_name FROM information_schema.columns WHERE table_name = 'citus_stat_activity'
ORDER BY 1;
