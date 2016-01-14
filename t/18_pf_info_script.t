#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 9;
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

#-------------------------------------------------------------------------------

# set up a temp dir
my $temp_dir = File::Temp->newdir;
dir( $temp_dir, 't' )->mkpath;
my $orig_cwd = getcwd;
symlink dir( $orig_cwd, qw( t data ) ), dir( $temp_dir, qw( t data ) )
  or die "ERROR: couldn't link data directory into temp directory";
chdir $temp_dir;

#-------------------------------------------------------------------------------

my $script = file( $orig_cwd, qw( bin pf ) );

# valid command line but no config
my ( $rv, $stdout, $stderr ) = run_script( $script, [ 'info', '-t', 'lane', '-i', '10018_1#1' ] );

like $stderr, qr/ERROR: config file \(prod\.conf\) doesn't exist/,
  'error about missing config on STDERR';

#---------------------------------------

# put the config in the expected location and try the same command again; this
# time it should work
copy file( qw( t data 18_pf_info_script prod.conf ) ), $temp_dir
  or die "copying prod.conf failed: $!";

( $rv, $stdout, $stderr ) = run_script( $script, [ 'info', '-t', 'lane', '-i', '10018_1#1' ] );

is $stderr, '', 'no output on STDERR';

#---------------------------------------

# write a CSV file
( $rv, $stdout, $stderr ) = run_script( $script, [ 'info', '-t', 'lane', '-i', '10018_1#1', '-o' ] );

like $stderr, qr/Wrote info to "infofind.csv"/, 'expected output on STDERR when writing CSV';

ok -f 'infofind.csv', 'found CSV file';

# try writing another CSV to same path
( $rv, $stdout, $stderr ) = run_script( $script, [ 'info', '-t', 'lane', '-i', '10018_1#1', '-o' ] );

like $stderr, qr/ERROR: CSV file "infofind.csv" already exists; not overwriting existing file/,
  'got error message about not overwriting';

# specify a different filename
( $rv, $stdout, $stderr ) = run_script( $script, [ 'info', '-t', 'lane', '-i', '10018_1#1', '-o', 'if.csv' ] );

like $stderr, qr/Wrote info to "if.csv"/, 'expected output on STDERR when writing CSV';

ok -f 'infofind.csv', 'found other CSV file';

#-------------------------------------------------------------------------------

my @log_lines = file('pathfind.log')->slurp;

is scalar @log_lines, 5, 'got expected number of log entries';

like $log_lines[0], qr|bin/pf info -t lane -i 10018_1#1$|, 'log looks sensible';

#-------------------------------------------------------------------------------

# done_testing;

chdir $orig_cwd;

