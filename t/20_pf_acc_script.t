#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;# tests => 9;
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
my ( $rv, $stdout, $stderr ) = run_script( $script, [ 'accession', '-t', 'lane', '-i', '10018_1#1' ] );

like $stderr, qr/ERROR: config file \(prod\.conf\) doesn't exist/,
  'error about missing config on STDERR';

#---------------------------------------

# put the config in the expected location and try the same command again; this
# time it should work
copy file( qw( t data 20_pf_acc_script prod.conf ) ), $temp_dir
  or die "copying prod.conf failed: $!";

( $rv, $stdout, $stderr ) = run_script( $script, [ 'accession', '-t', 'lane', '-i', '10018_1#1' ] );

is $stderr, '', 'no output on STDERR';

#---------------------------------------

# write a CSV file
( $rv, $stdout, $stderr ) = run_script( $script, [ 'accession', '-t', 'lane', '-i', '10018_1#1', '-o' ] );

like $stderr, qr/Wrote accessions to "accessionfind\.csv"/, 'expected output on STDERR when writing CSV';

ok -f 'accessionfind.csv', 'found CSV file';

# try writing another CSV to same path
( $rv, $stdout, $stderr ) = run_script( $script, [ 'accession', '-t', 'lane', '-i', '10018_1#1', '-o' ] );

like $stderr, qr/ERROR: output file "accessionfind\.csv" already exists/,
  'got error message about not overwriting';

# specify a different filename
( $rv, $stdout, $stderr ) = run_script( $script, [ 'accession', '-t', 'lane', '-i', '10018_1#1', '-o', 'af.csv' ] );

like $stderr, qr/Wrote accessions to "af.csv"/, 'expected output on STDERR when writing CSV';

ok -f 'af.csv', 'found other CSV file';

#-------------------------------------------------------------------------------

my @log_lines = file('pathfind.log')->slurp;

is scalar @log_lines, 5, 'got expected number of log entries';

like $log_lines[0], qr|bin/pf accession -t lane -i 10018_1#1$|, 'log looks sensible';

#-------------------------------------------------------------------------------

done_testing;

chdir $orig_cwd;

