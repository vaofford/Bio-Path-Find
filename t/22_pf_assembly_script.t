#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 10;
use Test::Exception;
use Test::Output;
use Test::Script::Run;
use File::Temp;
use File::Copy;
use Path::Class;
use Cwd;
use IPC::Open2;

# set up the "linked" directory for the test suite
use lib 't';

use Test::Setup;

unless ( -d dir( qw( t data linked ) ) ) {
  diag 'creating symlink directory';
  Test::Setup::make_symlinks;
}
delete $ENV{HARNESS_ACTIVE};
#-------------------------------------------------------------------------------

# set up a temp dir
my $temp_dir = File::Temp->newdir;
dir( $temp_dir, 't' )->mkpath;
my $orig_cwd = getcwd;
symlink dir( $orig_cwd, qw( t data ) ), dir( $temp_dir, qw( t data ) )
  or die "ERROR: couldn't link data directory into temp directory";
chdir $temp_dir;

#---------------------------------------

# explicitly unset environment variable pointing at config file
delete $ENV{PF_CONFIG_FILE};

my $script = file( $orig_cwd, qw( bin pf ) );
my ( $rv, $stdout, $stderr ) = run_script( $script );

# no arguments but no config file path defined
like $stderr, qr/ERROR: no config file defined/,
  'error about missing config on STDERR';

#---------------------------------------

# config file specified, but non-existent
$ENV{PF_CONFIG_FILE} = 'prod.conf';
( $rv, $stdout, $stderr ) = run_script( $script );

like $stderr, qr/ERROR: specified config file \(prod\.conf\) does not exist/,
  'error about non-existent config file on STDERR';

#---------------------------------------

# valid command line but non-existent config file
copy file( qw( t data 22_pf_assembly_script no_log.conf ) ), $temp_dir;
$ENV{PF_CONFIG_FILE} = 'no_log.conf';
( $rv, $stdout, $stderr ) = run_script( $script, [ 'assembly', '-t', 'lane', '-i', '10018_1#1' ] );

like $stderr, qr/ERROR: specified config file/,
  'error about missing log filename on STDERR';

#-------------------------------------------------------------------------------

# valid config, which includes path to log file

copy file( qw( t data 22_pf_assembly_script prod.conf ) ), $temp_dir;
$ENV{PF_CONFIG_FILE} = 'prod.conf';
run_ok( $script, [ qw( -h ) ], 'script runs ok with help flag' );
run_not_ok( $script, [ ], 'script exits with error status when run with no arguments' );

#---------------------------------------

( $rv, $stdout, $stderr ) = run_script( $script, [] );

like $stderr, qr/Missing command/, 'got expected error message with no flags';

#---------------------------------------

# put the config in the expected location and try the same command again; this
# time it should work
copy file( qw( t data 22_pf_assembly_script prod.conf ) ), $temp_dir;

( $rv, $stdout, $stderr ) = run_script( $script, [ 'assembly', '-t', 'lane', '-i', '10018_1#1' ] );

is $stdout, '', 'no output on STDOUT';
like $stderr, qr/No data found/, 'expected output on STDERR';

#---------------------------------------

my @log_lines = file('pathfind.log')->slurp;

is scalar @log_lines, 4, 'got expected number of log entries';

like $log_lines[3], qr|bin/pf assembly -t lane -i 10018_1#1$|, 'log line is correct';

#-------------------------------------------------------------------------------

# done_testing;

chdir $orig_cwd;

