
use strict;
use warnings;

use Test::More; # tests => 14;
use Test::Exception;
use Test::Warn;
use Path::Class;
use File::Copy;
use Cwd;

use Bio::Path::Find::DatabaseManager;

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

# set up a DBM

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
};

my $dbm = Bio::Path::Find::DatabaseManager->new(
  config      => $config,
  schema_name => 'tracking',
);

my $database  = $dbm->get_database('mapping_tests');
my @lane_rows = $database->schema->get_lanes_by_id('10018_1', 'lane')->all;

$lane_rows[0]->database($database);

my $lane;
lives_ok { $lane = Bio::Path::Find::Lane::Class::Map->new( row => $lane_rows[0] ) }
  'no exception when creating a Map Lane';

isa_ok $lane, 'Bio::Path::Find::Lane';

#-------------------------------------------------------------------------------

# shouldn't find any files when "is_qc" is true

# explicitly set "is_qc" for all mapstats rows for a lane
my $mapstats_row = $database->schema->resultset('Mapstat')->find( { row_id => 547908 } );
$mapstats_row->update( { is_qc => 1 } );

warnings_are { $lane->_get_bam } [], 'no warnings from "_get_bam"';

ok $lane->has_no_files, 'no files found when "is_qc" true';

#---------------------------------------

# reset "is_qc". Lane now has one mapstats row with "is_qc == 1", one with
# "is_qc == 0"
$mapstats_row->update(
  {
    is_qc  => 0,
    prefix => '_12345678_1234_',
  }
);

# touch a job status file. If the method finds that file for a given lane, it
# shouldn't return a path to a bam file
$job_status_file->touch;

warnings_are { $lane->_get_bam } [], 'no warnings from "_get_bam"';

ok $lane->has_no_files, 'no files found when job status file exists';

#---------------------------------------

$job_status_file->remove;

warnings_are { $lane->_get_bam } [], 'no warnings from "_get_bam"';

is $lane->file_count, 1, 'found one file';
is $lane->files->[0],
  't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1/544477.se.markdup.bam',
  'found expected file';






$DB::single = 1;

done_testing;

chdir $orig_cwd;

__END__

#---------------------------------------

# "_get_stats_row"

my $stats;
lives_ok { $stats = $lane->_get_stats_row('spades', 'contigs.fa.stats', $lane->files->[0]) }
  'no exception when getting stats row';

my $expected_stats = [
  607,
  'Scaffold: Correction, Normalisation, Primer Removal + SPAdes + Improvement',
  '10018_1#2',
  317093,
  'Streptococcus_suis_P1_7_v1',
  2007491,
  '0.0',
  'NA',
  2.4,
  5983,
  64,
  95,
  225633,
  30.9,
  3,
  1,
];

is_deeply $stats, $expected_stats, 'got expected stats row';

#---------------------------------------

# "_build_stats"

lives_ok { $stats = $lane->stats } 'no exception when getting all stats';

$expected_stats = [
  [
    607,
    'Scaffold: Correction, Normalisation, Primer Removal + SPAdes + Improvement',
    '10018_1#2',
    317093,
    'Streptococcus_suis_P1_7_v1',
    2007491,
    '0.0',
    'NA',
    2.4,
    5983,
    64,
    95,
    225633,
    30.9,
    3,
    1,
  ],
];

is_deeply $stats, $expected_stats, 'got expected stats';

#-------------------------------------------------------------------------------

# set up a new lane, this time one that has two GFF files, 10018_1#1

$lane_row = $lane_rows[0];
$lane_row->database($database);

# get a Lane

lives_ok { $lane = Bio::Path::Find::Lane::Class::Annotation->new( row => $lane_row ) }
  'no exception when creating an Annotation Lane';

ok $lane->does('Bio::Path::Find::Lane::Role::Stats'), 'lane has Stats Role applied';

# set it up to find the GFF file(s) for the lane
$lane->search_depth(3);
$lane->find_files('gff');

#---------------------------------------

# "_get_stats_row"

lives_ok { $stats = $lane->_get_stats_row('spades', 'contigs.fa.stats', $lane->files->[0]) }
  'no exception when getting stats row';

$expected_stats = [
  607,
  'Scaffold: Correction, Normalisation, Primer Removal + SPAdes + Improvement',
  '10018_1#1',
  397141,
  'Streptococcus_suis_P1_7_v1',
  2007491,
  '0.0',
  '0.00',
  2.3,
  2895,
  36,
  73,
  308610,
  30.9,
  3,
  1,
];

is_deeply $stats, $expected_stats, 'got expected stats row';

#---------------------------------------

# "_build_stats"

lives_ok { $stats = $lane->stats } 'no exception when getting all stats';

$expected_stats = [
  [
    607,
    'Scaffold: IVA',
    '10018_1#1',
    397141,
    'Streptococcus_suis_P1_7_v1',
    2007491,
    '0.0',
    '0.00',
    2.3,
    1167,
    3,
    341,
    385279,
    30.9,
    13,
    6,
  ],
  [
    607,
    'Scaffold: Correction, Normalisation, Primer Removal + SPAdes + Improvement',
    '10018_1#1',
    397141,
    'Streptococcus_suis_P1_7_v1',
    2007491,
    '0.0',
    '0.00',
    2.3,
    2895,
    36,
    73,
    308610,
    30.9,
    3,
    1,
  ],
];

is_deeply $stats, $expected_stats, 'got expected stats';

#-------------------------------------------------------------------------------

# done_testing;

