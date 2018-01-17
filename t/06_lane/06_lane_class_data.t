
use strict;
use warnings;

use Test::More tests => 13;
use Test::Exception;
use Test::Output;
use Test::Warn;
use Path::Class;
use File::Temp qw( tempdir );
use Cwd;

# set up the "linked" directory for the test suite
use lib 't';

use Test::Setup;

unless ( -d dir( qw( t data linked ) ) ) {
  diag 'creating symlink directory';
  Test::Setup::make_symlinks;
}
use_ok('Bio::Path::Find::DatabaseManager');

use Bio::Path::Find::DatabaseManager;

use Log::Log4perl qw( :easy );

# initialise l4p to avoid warnings
Log::Log4perl->easy_init( $FATAL );

use_ok('Bio::Path::Find::Lane::Class::Data');

#---------------------------------------

# set up a DBM

my $config = {
  db_root           => dir(qw( t data linked )),
  connection_params => {
    tracking => {
      driver       => 'SQLite',
      dbname       => file(qw( t data pathogen_prok_track.db )),
      schema_class => 'Bio::Track::Schema',
    },
  },
};

my $dbm = Bio::Path::Find::DatabaseManager->new(
  config      => $config,
  schema_name => 'tracking',
);

my $database  = $dbm->get_database('pathogen_prok_track');
my $lane_rows = $database->schema->get_lanes_by_id(['10018_1'], 'lane');

my $lane_row = $lane_rows->first;
$lane_row->database($database);

#---------------------------------------

# get a Lane

my $lane;

lives_ok { $lane = Bio::Path::Find::Lane::Class::Data->new( row => $lane_row ) }
  'no exception when creating B::P::F::Lane::Class::Data';

ok $lane->does('Bio::Path::Find::Lane::Role::Stats'), 'lane has Stats Role applied';

#-------------------------------------------------------------------------------

my $expected_stats = [
  [
    607,
    'APP_N2_OP1',
    '10018_1#1',
    47,
    397141,
    18665627,
    'QC',
    'Streptococcus_suis_P1_7_v1',
    2007491,
    'bwa',
    525354,
    '0.0',
    '0.0',
    0,
    '0.00',
    '0.01',
    '2.3',
    '90.2',
    '0.00',
    '0.0000',
    '0.044',
    'pending',
    'pending',
    1,
    '2.0868283360403e-05',
    '0.0112145340361108',
    '3.57142857142857',
    'Done',
    'Done',
    'Done',
    '-',
    '-',
    '-',
    'Done',
  ],
];

is_deeply $lane->stats, $expected_stats, 'got expected stats for lane';

#---------------------------------------

lives_ok { $lane->_get_fastq } 'no exception when finding fastq files';
ok $lane->has_files, 'lane has files';
is $lane->file_count, 1, 'found one fastq file';
is $lane->files->[0]->stringify,
  't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1/10018_1#1_1.fastq.gz',
  'got expected fastq file';

#---------------------------------------

$lane->clear_files;

lives_ok { $lane->_get_corrected } 'no exception when finding corrected files';
ok $lane->has_files, 'lane has files';
is $lane->file_count, 1, 'found one corrected file';
is $lane->files->[0]->stringify,
  't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1/10018_1#1.corrected.fasta.gz',
  'got expected corrected fasta file';

#---------------------------------------

# done_testing;

