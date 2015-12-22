#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Output;
use Test::Script::Run;
use File::Temp;
use File::Copy;
use Path::Class;
use Cwd;

#-------------------------------------------------------------------------------

# set up a temp dir
my $temp_dir = File::Temp->newdir;
dir( $temp_dir, 't' )->mkpath;
my $orig_cwd = getcwd;
symlink( "$orig_cwd/t/data", "$temp_dir/t/data") == 1
  or die "ERROR: couldn't link data directory into temp directory";
chdir $temp_dir;

#-------------------------------------------------------------------------------

my $script = "$orig_cwd/bin/pathfind";
my $log    = file( $temp_dir, 'pathfind.log' );

run_ok( $script, [ qw( -h ) ], 'script runs ok with help flag' );
run_not_ok( $script, [ ], 'script exits with error status when run with no arguments' );

#---------------------------------------

my ( $rv, $stdout, $stderr ) = run_script( $script, [] );

like $stderr, qr/Required option 'id' missing/, 'got expected error message with no flags';

#---------------------------------------

# valid command line but no config
( $rv, $stdout, $stderr ) = run_script( $script, [ '-t', 'lane', '-i', '10018_1#1' ] );

like $stderr, qr/ERROR: config file \(prod\.conf\) doesn't exist/,
  'error about missing config on STDERR';

#---------------------------------------

# put the config in the expected location and try the same command again; this
# time it should work
copy 't/data/16_pathfind_script/prod.conf', $temp_dir;

( $rv, $stdout, $stderr ) = run_script( $script, [ '-t', 'lane', '-i', '10018_1#1' ] );

is $stderr, '', 'no output on STDERR';
like $stdout, qr|prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/|,
  'got expected path on STDOUT';

#---------------------------------------

my @log_lines = $log->slurp;

is scalar @log_lines, 5, 'got expected number of log entries';

like $log_lines[0], qr|bin/pathfind -h$|, 'first log line is correct';
like $log_lines[1], qr|bin/pathfind$|,    'second log line is correct';
like $log_lines[4], qr|bin/pathfind -t lane -i 10018_1#1$|, 'fourth log line is correct';

#-------------------------------------------------------------------------------

done_testing;

chdir $orig_cwd;

