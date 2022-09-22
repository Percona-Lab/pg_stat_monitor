#!/usr/bin/perl

use strict;
use warnings;
use File::Basename;
use File::Compare;
use File::Copy;
use String::Util qw(trim);
use Test::More;
use lib 't';
use pgsm;

# Get filename and create out file name and dirs where requried
PGSM::setup_files_dir(basename($0));
                                                                                
if ($PGSM::PG_MAJOR_VERSION <= 12)
{                                                                               
    plan skip_all => "pg_stat_monitor test cases for versions 12 and below.";
}                                                                               

# Create new PostgreSQL node and do initdb
my $node = PGSM->pgsm_init_pg();
my $pgdata = $node->data_dir;

# Update postgresql.conf to include/load pg_stat_monitor library   
$node->append_conf('postgresql.conf', "shared_preload_libraries = 'pg_stat_statements,pg_stat_monitor'");
# Set bucket duration to 3600 seconds so bucket doesn't change.
$node->append_conf('postgresql.conf', "pg_stat_statements.track_utility = off");
$node->append_conf('postgresql.conf', "pg_stat_monitor.pgsm_bucket_time = 3600");
$node->append_conf('postgresql.conf', "track_io_timing = on");
$node->append_conf('postgresql.conf', "pg_stat_monitor.pgsm_track_utility = no");
$node->append_conf('postgresql.conf', "pg_stat_monitor.pgsm_normalized_query = yes");

# Start server
my $rt_value = $node->start;
ok($rt_value == 1, "Start Server");

# Create extension and change out file permissions
my ($cmdret, $stdout, $stderr) = $node->psql('postgres', 'CREATE EXTENSION pg_stat_statements;', extra_params => ['-a']);
ok($cmdret == 0, "Create PGSS Extension");
PGSM::append_to_file($stdout);

# Create extension and change out file permissions
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'CREATE EXTENSION pg_stat_monitor;', extra_params => ['-a']);
ok($cmdret == 0, "Create PGSM Extension");
PGSM::append_to_file($stdout);

# Run required commands/queries and dump output to out file.
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'SELECT pg_stat_monitor_reset();', extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
ok($cmdret == 0, "Reset PGSM Extension");
PGSM::append_to_file($stdout);

# Run required commands/queries and dump output to out file.
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'SELECT pg_stat_statements_reset();', extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
ok($cmdret == 0, "Reset PGSS Extension");
PGSM::append_to_file($stdout);

# Run 'SELECT * from pg_stat_monitor_settings;' two times and dump output to out file 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'SELECT * from pg_stat_monitor_settings;', extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
ok($cmdret == 0, "Print PGSM Extension Settings");
PGSM::append_to_file($stdout);

# Create example database and run pgbench init
# ($cmdret, $stdout, $stderr) = $node->psql('postgres', 'CREATE database example;', extra_params => ['-a']);
# ok($cmdret == 0, "Create Database example");
# PGSM::append_to_file($stdout);

my $port = $node->port;

my $out = system ("pgbench -i -s 100 -p $port postgres");
ok($cmdret == 0, "Perform pgbench init");

$out = system ("pgbench -c 10 -j 2 -t 10000 -p $port postgres");
ok($cmdret == 0, "Run pgbench");

($cmdret, $stdout, $stderr) = $node->psql('postgres', "Delete from pgbench_accounts where aid % 9 = 1;", extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
($cmdret, $stdout, $stderr) = $node->psql('postgres', "Delete from pgbench_accounts where aid % 10 = 1;", extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
($cmdret, $stdout, $stderr) = $node->psql('postgres', "Delete from pgbench_accounts where aid % 5 = 1;", extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
($cmdret, $stdout, $stderr) = $node->psql('postgres', "Delete from pgbench_accounts where aid % 3 = 1;", extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
($cmdret, $stdout, $stderr) = $node->psql('postgres', "Delete from pgbench_accounts where aid % 2 = 1;", extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select queryid, substr(query,0,130) as query, calls, rows, total_exec_time,min_exec_time,max_exec_time,mean_exec_time from pg_stat_statements where query Like \'%bench%\' order by query,calls desc;', extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
PGSM::append_to_debug_file($stdout);

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select client_ip, bucket, queryid, substr(query,0,130) as query, cmd_type_text, calls, rows_retrieved, total_exec_time, min_exec_time, max_exec_time, mean_exec_time, cpu_user_time, cpu_sys_time from pg_stat_monitor where query Like \'%bench%\' order by query,calls desc;', extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
PGSM::append_to_debug_file($stdout);

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'select substr(query,0,30) as query,calls,rows,shared_blks_hit,shared_blks_read,shared_blks_dirtied,shared_blks_written,local_blks_hit,local_blks_read,local_blks_dirtied,local_blks_written,temp_blks_read,temp_blks_written,blk_read_time,blk_write_time,wal_records,wal_fpi,wal_bytes from pg_stat_statements where query Like \'%bench%\' order by query,calls;', extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
PGSM::append_to_debug_file($stdout);

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select substr(query,0,30) as query,calls,rows_retrieved as rows, shared_blks_hit,shared_blks_read,shared_blks_dirtied,shared_blks_written,local_blks_hit,local_blks_read,local_blks_dirtied,local_blks_written,temp_blks_read,temp_blks_written,blk_read_time,blk_write_time,wal_records,wal_fpi,wal_bytes, cmd_type_text from pg_stat_monitor where query Like \'%bench%\' order by query,calls;', extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
PGSM::append_to_debug_file($stdout);

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'select substr(query,0,30),calls, rows, ROUND(total_exec_time::numeric,4) as total_exec_time, ROUND(min_exec_time::numeric,4) as min_exec_time, ROUND(max_exec_time::numeric,4) as max_exec_time, ROUND(mean_exec_time::numeric,4) as mean_exec_time, ROUND(stddev_exec_time::numeric,4) as stddev_exec_time, ROUND(blk_read_time::numeric,4) as blk_read_time, ROUND(blk_write_time::numeric,4) as blk_write_time, wal_records, wal_fpi, wal_bytes  from pg_stat_statements where query Like \'%bench%\' order by query,calls desc;', extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
PGSM::append_to_debug_file($stdout);

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'select substr(query,0,30), calls, rows_retrieved as rows, total_exec_time, min_exec_time, max_exec_time, mean_exec_time, stddev_exec_time, ROUND(blk_read_time::numeric,4) as blk_read_time, ROUND(blk_write_time::numeric,4) as blk_write_time, wal_records, wal_fpi, wal_bytes from pg_stat_monitor where query Like \'%bench%\' order by query,calls desc;', extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
PGSM::append_to_debug_file($stdout);
PGSM::append_to_debug_file("-------------");

# Compare values for query 'Delete from pgbench_accounts where $1 = $2' 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.calls = PGSS.calls from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%Delete from pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: calls are equal.");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.rows_retrieved = PGSS.rows from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%Delete from pgbench_accounts%\'; ', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: rows are equal).");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.total_exec_time = ROUND(PGSS.total_exec_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%Delete from pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: total_exec_time is equal.");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.min_exec_time = ROUND(PGSS.min_exec_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%Delete from pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: min_exec_time is equal.");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.max_exec_time = ROUND(PGSS.max_exec_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%Delete from pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: max_exec_time is equal.");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.mean_exec_time = ROUND(PGSS.mean_exec_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%Delete from pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: mean_exec_time is equal.");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.stddev_exec_time = ROUND(PGSS.stddev_exec_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%Delete from pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: stddev_exec_time is equal.");
 
#($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select ROUND(PGSM.blk_read_time::numeric,4) = ROUND(PGSS.blk_read_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%Delete from pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
#trim($stdout);
#is($stdout,'t',"Compare: blk_read_time is equal.");
 
#($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select ROUND(PGSM.blk_write_time::numeric,4) = ROUND(PGSS.blk_write_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%Delete from pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
#trim($stdout);
#is($stdout,'t',"Compare: blk_write_time is equal.");
 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.wal_records = PGSS.wal_records from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%Delete from pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: wal_records are equal.");
 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.wal_fpi = PGSS.wal_fpi from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%Delete from pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: wal_fpi is equal.");
 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.wal_bytes = PGSS.wal_bytes from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%Delete from pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: wal_bytes are equal.");

# Compare values for query 'INSERT INTO pgbench_history (tid, bid, aid, delta, mtime) VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)' 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.calls = PGSS.calls from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%INSERT INTO pgbench_history%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: calls are equal.");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.rows_retrieved = PGSS.rows from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%INSERT INTO pgbench_history%\'; ', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: rows are equal).");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.total_exec_time = ROUND(PGSS.total_exec_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%INSERT INTO pgbench_history%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: total_exec_time is equal.");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.min_exec_time = ROUND(PGSS.min_exec_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%INSERT INTO pgbench_history%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: min_exec_time is equal.");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.max_exec_time = ROUND(PGSS.max_exec_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%INSERT INTO pgbench_history%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: max_exec_time is equal.");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.mean_exec_time = ROUND(PGSS.mean_exec_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%INSERT INTO pgbench_history%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: mean_exec_time is equal.");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.stddev_exec_time = ROUND(PGSS.stddev_exec_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%INSERT INTO pgbench_history%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: stddev_exec_time is equal.");
 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select ROUND(PGSM.blk_read_time::numeric,4) = ROUND(PGSS.blk_read_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%INSERT INTO pgbench_history%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: blk_read_time is equal.");
 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select ROUND(PGSM.blk_write_time::numeric,4) = ROUND(PGSS.blk_write_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%INSERT INTO pgbench_history%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: blk_write_time is equal.");
 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.wal_records = PGSS.wal_records from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%INSERT INTO pgbench_history%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: wal_records are equal.");
 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.wal_fpi = PGSS.wal_fpi from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%INSERT INTO pgbench_history%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: wal_fpi is equal.");
 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.wal_bytes = PGSS.wal_bytes from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%INSERT INTO pgbench_history%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: wal_bytes are equal.");
 
# Compare values for query 'SELECT abalance FROM pgbench_accounts WHERE aid = $1' 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.calls = PGSS.calls from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%SELECT abalance FROM pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: calls are equal.");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.rows_retrieved = PGSS.rows from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%SELECT abalance FROM pgbench_accounts%\'; ', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: rows are equal).");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.total_exec_time = ROUND(PGSS.total_exec_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%SELECT abalance FROM pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: total_exec_time is equal.");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.min_exec_time = ROUND(PGSS.min_exec_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%SELECT abalance FROM pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: min_exec_time is equal.");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.max_exec_time = ROUND(PGSS.max_exec_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%SELECT abalance FROM pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: max_exec_time is equal.");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.mean_exec_time = ROUND(PGSS.mean_exec_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%SELECT abalance FROM pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: mean_exec_time is equal.");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.stddev_exec_time = ROUND(PGSS.stddev_exec_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%SELECT abalance FROM pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: stddev_exec_time is equal.");
 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select ROUND(PGSM.blk_read_time::numeric,4) = ROUND(PGSS.blk_read_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%SELECT abalance FROM pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: blk_read_time is equal.");
 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select ROUND(PGSM.blk_write_time::numeric,4) = ROUND(PGSS.blk_write_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%SELECT abalance FROM pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: blk_write_time is equal.");
 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.wal_records = PGSS.wal_records from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%SELECT abalance FROM pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: wal_records are equal.");
 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.wal_fpi = PGSS.wal_fpi from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%SELECT abalance FROM pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: wal_fpi is equal.");
 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.wal_bytes = PGSS.wal_bytes from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%SELECT abalance FROM pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: wal_bytes are equal.");

# Compare values for query 'UPDATE pgbench_accounts SET abalance = abalance + $1 WHERE aid = $2' 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.calls = PGSS.calls from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%UPDATE pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: calls are equal.");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.rows_retrieved = PGSS.rows from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%UPDATE pgbench_accounts%\'; ', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: rows are equal).");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.total_exec_time = ROUND(PGSS.total_exec_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%UPDATE pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: total_exec_time is equal.");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.min_exec_time = ROUND(PGSS.min_exec_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%UPDATE pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: min_exec_time is equal.");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.max_exec_time = ROUND(PGSS.max_exec_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%UPDATE pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: max_exec_time is equal.");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.mean_exec_time = ROUND(PGSS.mean_exec_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%UPDATE pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: mean_exec_time is equal.");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.stddev_exec_time = ROUND(PGSS.stddev_exec_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%UPDATE pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: stddev_exec_time is equal.");
 
#($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select ROUND(PGSM.blk_read_time::numeric,4) = ROUND(PGSS.blk_read_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%UPDATE pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
#trim($stdout);
#is($stdout,'t',"Compare: blk_read_time is equal.");
 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select ROUND(PGSM.blk_write_time::numeric,4) = ROUND(PGSS.blk_write_time::numeric,4) from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%UPDATE pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: blk_write_time is equal.");
 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.wal_records = PGSS.wal_records from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%UPDATE pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: wal_records are equal.");
 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.wal_fpi = PGSS.wal_fpi from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%UPDATE pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: wal_fpi is equal.");
 
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'Select PGSM.wal_bytes = PGSS.wal_bytes from pg_stat_monitor as PGSM INNER JOIN pg_stat_statements as PGSS ON PGSS.query = PGSM.query  where PGSM.query Like \'%UPDATE pgbench_accounts%\';', extra_params => ['-Pformat=unaligned','-Ptuples_only=on']);
trim($stdout);
is($stdout,'t',"Compare: wal_bytes are equal.");

# Drop extension
$stdout = $node->safe_psql('postgres', 'Drop extension pg_stat_monitor;',  extra_params => ['-a']);
ok($cmdret == 0, "Drop PGSM  Extension");
PGSM::append_to_file($stdout);

# Stop the server
$node->stop;

# Done testing for this testcase file.
done_testing();

