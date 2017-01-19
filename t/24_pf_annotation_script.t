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

copy file( qw( t data 24_pf_annotation_script prod.conf ) ), $temp_dir;
$ENV{PF_CONFIG_FILE} = 'prod.conf';

my $script = file( $orig_cwd, qw( bin pf ) );

my ( $rv, $stdout, $stderr ) = run_script( $script, [ 'annotation', '-t', 'lane', '-i', '10018_1#1' ] );

my $file_list = <<'EOF_output';
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1/iva_assembly/annotation/10018_1#1.gff
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1/spades_assembly/annotation/10018_1#1.gff
EOF_output

is $stdout, $file_list, 'got expected GFF file list on STDOUT';

#---------------------------------------

( $rv, $stdout, $stderr ) = run_script( $script, [ 'annotation', '-t', 'lane', '-i', '10018_1#1', '-f', 'fasta' ] );

$file_list = <<'EOF_output';
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1/iva_assembly/annotation/10018_1#1.faa
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1/spades_assembly/annotation/10018_1#1.faa
EOF_output
is $stdout, $file_list, 'got expected fasta file list on STDOUT';

#---------------------------------------

( $rv, $stdout, $stderr ) = run_script( $script, [ 'annotation', '-t', 'lane', '-i', '10018_1#1', '-P', 'spades' ] );

$file_list = <<'EOF_output';
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1/spades_assembly/annotation/10018_1#1.gff
EOF_output
is $stdout, $file_list, 'got only a spades assembly on STDOUT';

#---------------------------------------

( $rv, $stdout, $stderr ) = run_script( $script, [ 'annotation', '-t', 'lane', '-i', '10018_1#1', '-g', 'gag', '-P', 'iva' ] );

like $stdout, qr|Samples containing gene:\t1.*missing gene:   \t+0|s,
  'got expected gene-finding output';

#---------------------------------------

( $rv, $stdout, $stderr ) = run_script( $script, [ 'annotation', '-t', 'lane', '-i', '10018_1#1', '-p', 'HIV_PBS' ] );

like $stdout, qr|10018_1#1\.gff.*?containing gene/product:\s+1.*missing gene/product:\s+1|s,
  'got expected product-finding output';

#---------------------------------------

( $rv, $stdout, $stderr ) = run_script( $script, [ 'annotation', '-t', 'lane', '-i', '10018_1#1', '-g', 'gag', '-p', 'HIV_PBS' ] );

like $stdout, qr|10018_1#1\.gff.*?containing gene/product:\s+2.*missing gene/product:\s+0|s,
  'got expected gene/product-finding output';
like $stderr, qr/WARNING: searching for genes.*?Ignoring product name "HIV_PBS".*?products named "gag"/s,
  'got expected warning about mixing "-g" and "-p"';

#---------------------------------------

my @log_lines = file('pathfind.log')->slurp;

is scalar @log_lines, 6, 'got expected number of log entries';

like $log_lines[-1], qr|bin/pf annotation -t lane -i 10018_1#1|, 'log line is correct';

#-------------------------------------------------------------------------------

# done_testing;

chdir $orig_cwd;

__DATA__
