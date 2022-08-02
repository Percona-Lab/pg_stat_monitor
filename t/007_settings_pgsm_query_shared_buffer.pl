#!/usr/bin/perl

use strict;
use warnings;
use File::Basename;
use File::Compare;
use PostgresNode;
use Test::More;

# Expected folder where expected output will be present
my $expected_folder = "t/expected";

# Results/out folder where generated results files will be placed
my $results_folder = "t/results";

# Check if results folder exists or not, create if it doesn't
unless (-d $results_folder)
{
   mkdir $results_folder or die "Can't create folder $results_folder: $!\n";;
}

# Check if expected folder exists or not, bail out if it doesn't
unless (-d $expected_folder)
{
   BAIL_OUT "Expected files folder $expected_folder doesn't exist: \n";;
}

# Get filename of the this perl file
my $perlfilename = basename($0);

#Remove .pl from filename and store in a variable
$perlfilename =~ s/\.[^.]+$//;
my $filename_without_extension = $perlfilename;

# Create expected filename with path
my $expected_filename = "${filename_without_extension}.out";
my $expected_filename_with_path = "${expected_folder}/${expected_filename}" ;

# Create results filename with path
my $out_filename = "${filename_without_extension}.out";
my $out_filename_with_path = "${results_folder}/${out_filename}" ;

# Delete already existing result out file, if it exists.
if ( -f $out_filename_with_path)
{
   unlink($out_filename_with_path) or die "Can't delete already existing $out_filename_with_path: $!\n";
}

# Create new PostgreSQL node and do initdb
my $node = PostgresNode->get_new_node('test');
my $pgdata = $node->data_dir;
$node->dump_info;
$node->init;
                                                                                
# Update postgresql.conf to include/load pg_stat_monitor library
open my $conf, '>>', "$pgdata/postgresql.conf";
print $conf "shared_preload_libraries = 'pg_stat_monitor'\n";
print $conf "pg_stat_monitor.pgsm_bucket_time = 300\n";
print $conf "pg_stat_monitor.pgsm_query_shared_buffer = 1\n";
print $conf "pg_stat_monitor.pgsm_normalized_query = 'yes'\n";
close $conf;

# Start server
my $rt_value = $node->start;
ok($rt_value == 1, "Start Server");

# Create extension and change out file permissions
my ($cmdret, $stdout, $stderr) = $node->psql('postgres', 'CREATE EXTENSION pg_stat_monitor;', extra_params => ['-a']);
ok($cmdret == 0, "Create PGSM Extension");
TestLib::append_to_file($out_filename_with_path, $stdout . "\n");
chmod(0640 , $out_filename_with_path)
    or die("unable to set permissions for $out_filename_with_path");

# Run required commands/queries and dump output to out file.
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'SELECT pg_stat_monitor_reset();', extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
ok($cmdret == 0, "Reset PGSM Extension");
TestLib::append_to_file($out_filename_with_path, $stdout . "\n");

($cmdret, $stdout, $stderr) = $node->psql('postgres', "SELECT * from pg_stat_monitor_settings where name='pg_stat_monitor.pgsm_query_shared_buffer';", extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
ok($cmdret == 0, "Print PGSM Extension Settings");
TestLib::append_to_file($out_filename_with_path, $stdout . "\n");

# Create example database and run pgbench init
($cmdret, $stdout, $stderr) = $node->psql('postgres', 'CREATE database example;', extra_params => ['-a']);
print "cmdret $cmdret\n";
ok($cmdret == 0, "Create Database example");
TestLib::append_to_file($out_filename_with_path, $stdout . "\n");

my $port = $node->port;
print "port $port \n";

my $out = system ("pgbench -i -s 100 -p $port example");
print " out: $out \n" ;
ok($cmdret == 0, "Perform pgbench init");

$out = system ("pgbench -c 10 -j 2 -t 1000 -p $port example");
print " out: $out \n" ;
ok($cmdret == 0, "Run pgbench");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'select datname, substr(query,0,150) as query, calls from pg_stat_monitor order by datname, query, calls desc Limit 20;', extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
print "cmdret $cmdret\n";
ok($cmdret == 0, "Select XXX from pg_stat_monitor");
TestLib::append_to_file($out_filename_with_path, $stdout . "\n");

$node->append_conf('postgresql.conf', "pg_stat_monitor.pgsm_query_shared_buffer = 100\n");
$node->restart();

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'SELECT pg_stat_monitor_reset();', extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
ok($cmdret == 0, "Reset PGSM Extension");
TestLib::append_to_file($out_filename_with_path, $stdout . "\n");

($cmdret, $stdout, $stderr) = $node->psql('postgres', "SELECT * from pg_stat_monitor_settings where name='pg_stat_monitor.pgsm_query_shared_buffer';", extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
ok($cmdret == 0, "Print PGSM Extension Settings");
TestLib::append_to_file($out_filename_with_path, $stdout . "\n");

$out = system ("pgbench -i -s 100 -p $port example");
print " out: $out \n" ;
ok($cmdret == 0, "Perform pgbench init");

$out = system ("pgbench -c 10 -j 2 -t 1000 -p $port example");
print " out: $out \n" ;
ok($cmdret == 0, "Run pgbench");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'select datname, substr(query,0,150) as query, calls from pg_stat_monitor order by datname, query, calls desc Limit 20;', extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
print "cmdret $cmdret\n";
ok($cmdret == 0, "Select XXX from pg_stat_monitor");
TestLib::append_to_file($out_filename_with_path, $stdout . "\n");

$node->append_conf('postgresql.conf', "pg_stat_monitor.pgsm_query_shared_buffer = 20\n");
$node->restart();

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'SELECT pg_stat_monitor_reset();', extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
ok($cmdret == 0, "Reset PGSM Extension");
TestLib::append_to_file($out_filename_with_path, $stdout . "\n");

($cmdret, $stdout, $stderr) = $node->psql('postgres', "SELECT * from pg_stat_monitor_settings where name='pg_stat_monitor.pgsm_query_shared_buffer';", extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
ok($cmdret == 0, "Print PGSM Extension Settings");
TestLib::append_to_file($out_filename_with_path, $stdout . "\n");

$out = system ("pgbench -i -s 100 -p $port example");
print " out: $out \n" ;
ok($cmdret == 0, "Perform pgbench init");

$out = system ("pgbench -c 10 -j 2 -t 1000 -p $port example");
print " out: $out \n" ;
ok($cmdret == 0, "Run pgbench");

($cmdret, $stdout, $stderr) = $node->psql('postgres', 'select datname, substr(query,0,150) as query, calls from pg_stat_monitor order by datname, query, calls desc Limit 20;', extra_params => ['-a', '-Pformat=aligned','-Ptuples_only=off']);
print "cmdret $cmdret\n";
ok($cmdret == 0, "Select XXX from pg_stat_monitor");
TestLib::append_to_file($out_filename_with_path, $stdout . "\n");

# Drop extension
$stdout = $node->safe_psql('postgres', 'Drop extension pg_stat_monitor;',  extra_params => ['-a']);
ok($cmdret == 0, "Drop PGSM  Extension");
TestLib::append_to_file($out_filename_with_path, $stdout . "\n");

# Stop the server
$node->stop;

# compare the expected and out file
my $compare = compare($expected_filename_with_path, $out_filename_with_path);

# Test/check if expected and result/out file match. If Yes, test passes.
is($compare,0,"Compare Files: $expected_filename_with_path and $out_filename_with_path match.");

# Done testing for this testcase file.
done_testing();

