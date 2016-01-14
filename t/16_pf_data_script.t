#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 11;
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

run_ok( $script, [ qw( -h ) ], 'script runs ok with help flag' );
run_not_ok( $script, [ ], 'script exits with error status when run with no arguments' );

#---------------------------------------

my ( $rv, $stdout, $stderr ) = run_script( $script, [] );

like $stderr, qr/Missing command/, 'got expected error message with no flags';

#---------------------------------------

# valid command line but no config
( $rv, $stdout, $stderr ) = run_script( $script, [ 'data', '-t', 'lane', '-i', '10018_1#1' ] );

like $stderr, qr/ERROR: config file \(prod\.conf\) doesn't exist/,
  'error about missing config on STDERR';

#---------------------------------------

# put the config in the expected location and try the same command again; this
# time it should work
copy file( qw( t data 16_pf_data_script prod.conf ) ), $temp_dir;

( $rv, $stdout, $stderr ) = run_script( $script, [ 'data', '-t', 'lane', '-i', '10018_1#1' ] );

is $stderr, '', 'no output on STDERR';

SKIP: {
  skip "can't check paths except on unix", 1,
    unless file( qw( t data linked ) ) eq 't/data/linked';

  like $stdout, qr|prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/|,
    'got expected path on STDOUT';
};

#---------------------------------------

# this is really testing functionality in AppRole::BUILD, but we can't test it
# without a wrapper script, so here it is

# make sure we can pass in IDs via STDIN

my ( $child_in, $child_out );
my $pid = open2 $child_out, $child_in, $script, qw( data -t file --file-id-type lane -i - );

print $child_in "10018_1\n";
print $child_in "5477_6\n";

close $child_in;

waitpid( $pid, 0 );

my $found = 0;
while ( <$child_out> ) {
  $found++ if m/10018_1|5477_6/;
}

is $found, 61, 'got expected paths on STDOUT with IDs on STDIN';

#---------------------------------------

my @log_lines = file('pathfind.log')->slurp;

is scalar @log_lines, 6, 'got expected number of log entries';

like $log_lines[0], qr|bin/pf -h$|, 'first log line is correct';
like $log_lines[1], qr|bin/pf$|,    'second log line is correct';
like $log_lines[4], qr|bin/pf data -t lane -i 10018_1#1$|, 'fourth log line is correct';

#-------------------------------------------------------------------------------

# done_testing;

chdir $orig_cwd;

