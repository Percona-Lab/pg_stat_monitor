CREATE EXTENSION pg_stat_monitor;
SELECT pg_stat_monitor_reset();

CREATE OR REPLACE FUNCTION add(int, int) RETURNS INTEGER AS
$$
BEGIN
	return (select $1 + $2);
END; $$ language plpgsql;

CREATE OR REPLACE function add2(int, int) RETURNS int as
$$
BEGIN
	return add($1,$2);
END;
$$ language plpgsql;

SELECT add2(1,2);
SELECT query, top_query FROM pg_stat_monitor ORDER BY query COLLATE "C";

ALTER SYSTEM SET pg_stat_monitor.track TO 'all';
SELECT pg_reload_conf();
SELECT pg_sleep(1);
SELECT pg_stat_monitor_reset();

CREATE OR REPLACE FUNCTION add(int, int) RETURNS INTEGER AS
$$
BEGIN
	return (select $1 + $2);
END; $$ language plpgsql;

CREATE OR REPLACE function add2(int, int) RETURNS int as
$$
BEGIN
	return add($1,$2);
END;
$$ language plpgsql;

SELECT add2(1,2);
SELECT query, top_query FROM pg_stat_monitor ORDER BY query COLLATE "C";
ALTER SYSTEM SET pg_stat_monitor.track TO 'top';
SELECT pg_reload_conf();
SELECT pg_sleep(1);
SELECT pg_stat_monitor_reset();

DROP EXTENSION pg_stat_monitor;
