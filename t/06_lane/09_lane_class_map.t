
use strict;
use warnings;

use Test::More tests => 22;
use Test::Exception;
use Test::Warn;
use Test::Output;
use Path::Class;
use File::Copy;
use Cwd;

use Bio::Path::Find::Finder;

# set up logging
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init( $FATAL ); # initialise l4p to avoid warnings

# set up the "linked" directory for the test suite
use lib 't';

use Test::Setup;

unless ( -d dir( qw( t data linked ) ) ) {
  diag 'creating symlink directory';
  Test::Setup::make_symlinks;
}

# set up a temp dir where we can write files
my $temp_dir = File::Temp->newdir;
dir( $temp_dir, 't' )->mkpath;
my $orig_cwd = getcwd;
symlink dir( $orig_cwd, qw( t data ) ), dir( $temp_dir, qw( t data ) )
  or die "ERROR: couldn't link data directory into temp directory";

# clone the "pathogen_prok_track.db" SQLite database, so that we can
# modify it without changing the "master copy"
copy file( $orig_cwd, qw( t data pathogen_prok_track.db ) ),
     file( $temp_dir, 'mapping_tests.db' );

chdir $temp_dir;

# clean up any files that might have been left over after previous failed
# test runs
my $job_status_file;
{
  no warnings 'qw';
  $job_status_file =
    file( qw(t data master hashed_lanes pathogen_prok_track a 0 9 9 10018_1#1 _12345678_1234_job_status ) );
}
$job_status_file->remove;

# make sure we can compile the class that we're testing...
use_ok('Bio::Path::Find::Lane::Class::Map');

#---------------------------------------

# use the Finder to get some lanes to play with
my $config = {
  db_root           => dir(qw( t data linked )),
  connection_params => {
    tracking => {
      driver       => 'SQLite',
      # use the clone of the "pathogen_prok_track.db" SQLite DB
      dbname       => file('mapping_tests.db'),
      schema_class => 'Bio::Track::Schema',
    },
  },
  # map the cloned DB to the same set of files on disk
  db_subdirs => {
    mapping_tests => 'prokaryotes',
  },
  no_progress_bars => 1,
};

my $finder = Bio::Path::Find::Finder->new(
  config     => $config,
  lane_class => 'Bio::Path::Find::Lane::Class::Map'
);

my $lanes;
lives_ok { $lanes = $finder->find_lanes( ids => [ '10018_1' ], type => 'lane' ) }
  'no exception when finding lanes';

my $lane = $lanes->[0];

isa_ok $lane, 'Bio::Path::Find::Lane';
isa_ok $lane, 'Bio::Path::Find::Lane::Class::Map';

#-------------------------------------------------------------------------------

# test the "_get_bam" method

# shouldn't find any files when "is_qc" is true

# for this lane, one of the mapstats rows is already flagged as being a QC
# mapping ("is_qc == 1"). Explicitly set "is_qc" for the other mapstats row too
my $mapstats_row = $lane->row->database->schema->resultset('Mapstat')->find( { mapstats_id => 544477 } );
$mapstats_row->update( { is_qc => 1 } );

warnings_are { $lane->_get_bam } [], 'no warnings from "_get_bam"';
ok $lane->has_no_files, 'no files found when "is_qc" true';

#---------------------------------------

# reset "is_qc". Lane now has one mapstats row with "is_qc == 1", one with
# "is_qc == 0"

$mapstats_row->update( { is_qc  => 0, prefix => '_12345678_1234_' } );

# touch a job status file. If the method finds that file for a given lane, it
# shouldn't return a path to a bam file
$job_status_file->touch;

warnings_are { $lane->_get_bam } [], 'no warnings from "_get_bam"';
ok $lane->has_no_files, 'no files found when job status file exists';

#---------------------------------------

# when there is no job status file, we should find one file for this lane

$job_status_file->remove;

warnings_are { $lane->_get_bam } [], 'no warnings from "_get_bam"';

is $lane->file_count, 2, 'found mapping file plus index';
is $lane->files->[0],
  't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1/544477.se.markdup.bam',
  'found expected mapping file';

is $lane->files->[1],
    't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1/544477.se.markdup.bam.bai',
    'found expected index file';
#---------------------------------------

# check the paired end/single end filename distinction

$lane = $lanes->[1];

warnings_are { $lane->_get_bam } [], 'no warnings from "_get_bam"';

is $lane->file_count, 1, 'found one file, flagged as paired end';
is $lane->files->[0],
  't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_2/SLX/APP_IN_2_7492527/10018_1#2/544570.pe.markdup.bam',
  'found expected paired end bam file';

#---------------------------------------

# make sure _get_bam works with multiple mapstats rows

$lane = $lanes->[4];

warnings_are { $lane->_get_bam } [], 'no warnings from "_get_bam"';

is $lane->file_count, 3, 'found two files';
is_deeply $lane->files,
  [
    't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N1_OP2/SLX/APP_N1_OP2_7492529/10018_1#5/525342.se.markdup.bam',
    't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N1_OP2/SLX/APP_N1_OP2_7492529/10018_1#5/544510.se.markdup.bam',
    't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N1_OP2/SLX/APP_N1_OP2_7492529/10018_1#5/544510.se.markdup.bam.bai',
  ],
  'got expected file paths';

#-------------------------------------------------------------------------------

# "print_details"
my $expected_result = 't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1/544477.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	[\d]{4}-[\d]{2}-[\d]{2}T[\d]{2}:[\d]{2}:[\d]{2}
';
stdout_like { $lanes->[0]->print_details } qr/$expected_result/, 'got expected details for lane with one mapping';


$expected_result = 't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N1_OP2/SLX/APP_N1_OP2_7492529/10018_1#5/525342.se.markdup.bam	Streptococcus_suis_P1_7_v1	bwa	[\d]{4}-[\d]{2}-[\d]{2}T[\d]{2}:[\d]{2}:[\d]{2}
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N1_OP2/SLX/APP_N1_OP2_7492529/10018_1#5/544510.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	[\d]{4}-[\d]{2}-[\d]{2}T[\d]{2}:[\d]{2}:[\d]{2}
';
stdout_like { $lanes->[4]->print_details }
  qr/$expected_result/,
  'got expected details for lane with two mappings';

#-------------------------------------------------------------------------------

# check the "stats" attribute; calls "_build_stats", which calls "_get_stats_row"

my $expected_stats = [
  [
    607,
    'APP_N2_OP1',
    '10018_1#1',
    47,
    397141,
    18665627,
    'Mapping',
    'Streptococcus_suis_P1_7_v1',
    2007491,
    'smalt',
    544477,
    '1.3',
    '0.0',
    undef,
    '0.10',
    '2.97',
    '0.7',
    '0.4',
    '0.3',
    '0.0',
    undef
  ]
];

is_deeply $lanes->[0]->stats, $expected_stats, 'got expected stats for lane with one mapping';

$expected_stats= [
  [
    607,
    'APP_N1_OP2',
    '10018_1#5',
    47,
    304254,
    14299938,
    'Mapping',
    'Streptococcus_suis_P1_7_v1',
    2007491,
    'bwa',
    525342,
    '0.0',
    '0.0',
    0,
    '0.00',
    '0.00',
    undef,
    undef,
    undef,
    undef,
    undef
  ],
  [
    607,
    'APP_N1_OP2',
    '10018_1#5',
    47,
    304254,
    14299938,
    'Mapping',
    'Streptococcus_suis_P1_7_v1',
    2007491,
    'smalt',
    544510,
    '1.2',
    '0.0',
    undef,
    '0.09',
    '2.47',
    '0.5',
    '0.3',
    '0.2',
    '0.1',
    '0.0'
  ]
];

is_deeply $lanes->[4]->stats, $expected_stats, 'got expected stats for lane with two mappings';

#-------------------------------------------------------------------------------

# done_testing;

chdir $orig_cwd;

