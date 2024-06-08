--
-- Statement level tracking
--

SELECT setting::integer < 140000 AS skip_test FROM pg_settings where name = 'server_version_num'  \gset
\if :skip_test
\quit
\endif

CREATE EXTENSION pg_stat_monitor;
SET pg_stat_monitor.pgsm_track_utility = TRUE;
SET pg_stat_monitor.pgsm_normalized_query = TRUE;
SELECT pg_stat_monitor_reset();

-- DO block - top-level tracking.
CREATE TABLE stats_track_tab (x int);
SET pg_stat_monitor.pgsm_track = 'top';
DELETE FROM stats_track_tab;
DO $$
BEGIN
  DELETE FROM stats_track_tab;
END;
$$ LANGUAGE plpgsql;
SELECT toplevel, calls, query FROM pg_stat_monitor
  WHERE query LIKE '%DELETE%' ORDER BY query COLLATE "C", toplevel;
SELECT pg_stat_monitor_reset();

-- DO block - all-level tracking.
SET pg_stat_monitor.pgsm_track = 'all';
DELETE FROM stats_track_tab;
DO $$
BEGIN
  DELETE FROM stats_track_tab;
END; $$;
DO LANGUAGE plpgsql $$
BEGIN
  -- this is a SELECT
  PERFORM 'hello world'::TEXT;
END; $$;
SELECT toplevel, calls, query FROM pg_stat_monitor
  ORDER BY query COLLATE "C", toplevel;

-- DO block - top-level tracking without utility.
SET pg_stat_monitor.pgsm_track = 'top';
SET pg_stat_monitor.pgsm_track_utility = FALSE;
SELECT pg_stat_monitor_reset();
DELETE FROM stats_track_tab;
DO $$
BEGIN
  DELETE FROM stats_track_tab;
END; $$;
DO LANGUAGE plpgsql $$
BEGIN
  -- this is a SELECT
  PERFORM 'hello world'::TEXT;
END; $$;
SELECT toplevel, calls, query FROM pg_stat_monitor
  ORDER BY query COLLATE "C", toplevel;

-- DO block - all-level tracking without utility.
SET pg_stat_monitor.pgsm_track = 'all';
SELECT pg_stat_monitor_reset();
DELETE FROM stats_track_tab;
DO $$
BEGIN
  DELETE FROM stats_track_tab;
END; $$;
DO LANGUAGE plpgsql $$
BEGIN
  -- this is a SELECT
  PERFORM 'hello world'::TEXT;
END; $$;
SELECT toplevel, calls, query FROM pg_stat_monitor
  ORDER BY query COLLATE "C", toplevel;

-- PL/pgSQL function - top-level tracking.
SET pg_stat_monitor.pgsm_track = 'top';
SET pg_stat_monitor.pgsm_track_utility = FALSE;
SELECT pg_stat_monitor_reset();
CREATE FUNCTION PLUS_TWO(i INTEGER) RETURNS INTEGER AS $$
DECLARE
  r INTEGER;
BEGIN
  SELECT (i + 1 + 1.0)::INTEGER INTO r;
  RETURN r;
END; $$ LANGUAGE plpgsql;

SELECT PLUS_TWO(3);
SELECT PLUS_TWO(7);

-- SQL function --- use LIMIT to keep it from being inlined
CREATE FUNCTION PLUS_ONE(i INTEGER) RETURNS INTEGER AS
$$ SELECT (i + 1.0)::INTEGER LIMIT 1 $$ LANGUAGE SQL;

SELECT PLUS_ONE(8);
SELECT PLUS_ONE(10);

SELECT calls, rows, query FROM pg_stat_monitor ORDER BY query COLLATE "C";

-- immutable SQL function --- can be executed at plan time
CREATE FUNCTION PLUS_THREE(i INTEGER) RETURNS INTEGER AS
$$ SELECT i + 3 LIMIT 1 $$ IMMUTABLE LANGUAGE SQL;

SELECT PLUS_THREE(8);
SELECT PLUS_THREE(10);

SELECT toplevel, calls, rows, query FROM pg_stat_monitor ORDER BY query COLLATE "C";

-- PL/pgSQL function - all-level tracking.
SET pg_stat_monitor.pgsm_track = 'all';
SELECT pg_stat_monitor_reset();

-- we drop and recreate the functions to avoid any caching funnies
DROP FUNCTION PLUS_ONE(INTEGER);
DROP FUNCTION PLUS_TWO(INTEGER);
DROP FUNCTION PLUS_THREE(INTEGER);

-- PL/pgSQL function
CREATE FUNCTION PLUS_TWO(i INTEGER) RETURNS INTEGER AS $$
DECLARE
  r INTEGER;
BEGIN
  SELECT (i + 1 + 1.0)::INTEGER INTO r;
  RETURN r;
END; $$ LANGUAGE plpgsql;

SELECT PLUS_TWO(-1);
SELECT PLUS_TWO(2);

-- SQL function --- use LIMIT to keep it from being inlined
CREATE FUNCTION PLUS_ONE(i INTEGER) RETURNS INTEGER AS
$$ SELECT (i + 1.0)::INTEGER LIMIT 1 $$ LANGUAGE SQL;

SELECT PLUS_ONE(3);
SELECT PLUS_ONE(1);

SELECT calls, rows, query FROM pg_stat_monitor ORDER BY query COLLATE "C";

-- immutable SQL function --- can be executed at plan time
CREATE FUNCTION PLUS_THREE(i INTEGER) RETURNS INTEGER AS
$$ SELECT i + 3 LIMIT 1 $$ IMMUTABLE LANGUAGE SQL;

SELECT PLUS_THREE(8);
SELECT PLUS_THREE(10);

SELECT toplevel, calls, rows, query FROM pg_stat_monitor ORDER BY query COLLATE "C";

--
-- pg_stat_monitor.pgsm_track = none
--
SET pg_stat_monitor.pgsm_track = 'none';
SELECT pg_stat_monitor_reset();

SELECT 1 AS "one";
SELECT 1 + 1 AS "two";

SELECT calls, rows, query FROM pg_stat_monitor ORDER BY query COLLATE "C";
SELECT pg_stat_monitor_reset();

DROP EXTENSION pg_stat_monitor;