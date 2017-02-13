
use strict;
use warnings;

use Test::More tests => 25;
use Test::Exception;
use Path::Class;

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

use_ok('Bio::Path::Find::Lane::Class::Assembly');

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

# get a Lane
my $lane;

lives_ok { $lane = Bio::Path::Find::Lane::Class::Assembly->new( row => $lane_row ) }
  'no exception when creating an Assembly Lane';

ok $lane->does('Bio::Path::Find::Lane::Role::Stats'), 'lane has Stats Role applied';

#---------------------------------------

# "_get_assembly_type"

my $assembly_type;

# simple spades assembly
lives_ok { $assembly_type = $lane->_get_assembly_type( dir( qw( t data 06_lane 07_lane_class_assembly spades_assembly ) ), 'unscaffolded_contigs.fa.stats') }
  'no exception when getting assembly type string for unscaffolded contigs';

is $assembly_type, 'Contig: Correction, Normalisation, Primer Removal + SPAdes + Improvement',
  'got expected assembly type string';

# switch to scaffold
lives_ok { $assembly_type = $lane->_get_assembly_type( dir( qw( t data 06_lane 07_lane_class_assembly spades_assembly ) ), 'contigs.fa.stats') }
  'no exception when getting assembly type string for scaffold';

is $assembly_type, 'Scaffold: Correction, Normalisation, Primer Removal + SPAdes + Improvement',
  'got expected assembly type string';

# check the behaviour when there's no "pipeline_version"*" file
lives_ok { $assembly_type = $lane->_get_assembly_type( dir( qw( t data ) ), 'contigs.fa.stats') }
  'no exception when trying to get assembly type string';

is $assembly_type, undef, 'assembly type string undef with no pipeline_version_* file';

# change the version number of the pipeline
lives_ok { $assembly_type = $lane->_get_assembly_type( dir( qw( t data 06_lane 07_lane_class_assembly different_pipeline ) ), 'contigs.fa.stats') }
  'no exception when getting assembly type string';

is $assembly_type, 'Scaffold: Correction + Velvet + Improvement',
  'got correct assembly type with different pipeline version';

#---------------------------------------

# "_edit_filenames'

my $src_path = file( '12345_1#1', 'spades_assembly', 'contigs.fa' );
my $dst_path = file( 'my_output_dir', 'output.txt' );

my ( $returned_src_path, $returned_dst_path ) = $lane->_edit_filenames( $src_path, $dst_path );

is $returned_src_path, $src_path, '"_edit_filenames" returns original src_path';
is $returned_dst_path, file('my_output_dir', '12345_1#1.contigs_spades.fa'),
  '"_edit_filenames" returns expected path';

#---------------------------------------

# "_get_stats_row"

my $stats;
lives_ok { $stats = $lane->_get_stats_row( 'spades', 'contigs.fa.stats') }
  'no exception when getting stats row for spades';

my $expected_stats = [
  "10018_1#1",
  "Scaffold: Correction, Normalisation, Primer Removal + SPAdes + Improvement",
  2895,
  36,
  80.42,
  408,
  73,
  12,
  70,
  16,
  66,
  20,
  62,
  25,
  48,
  30,
  46,
  36,
  0,
  609334,
  308610,
  300724,
  97634,
  210976,
  32904036,
  16664940,
  16634476,
  54,
  54,
  30.9,
  73.4,
  12.9,
];

is_deeply $stats, $expected_stats, 'got expected stats row';

#---------------------------------------

# "_build_stats"

lives_ok { $stats = $lane->stats } 'no exception when getting all stats';

$expected_stats = [
  [
    '10018_1#1',
    'Scaffold: IVA',
    1167,
    3,
    '389.00',
    520,
    341,
    2,
    341,
    2,
    341,
    2,
    306,
    3,
    306,
    3,
    306,
    3,
    0,
    609334,
    385279,
    224055,
    258922,
    126357,
    32904036,
    20805066,
    20725864,
    54,
    54,
    30.9,
    299.3,
    102.4,
  ],
  [
    '10018_1#1',
    'Scaffold: Correction, Normalisation, Primer Removal + SPAdes + Improvement',
    2895,
    36,
    80.42,
    408,
    73,
    12,
    70,
    16,
    66,
    20,
    62,
    25,
    48,
    30,
    46,
    36,
    0,
    609334,
    308610,
    300724,
    97634,
    210976,
    32904036,
    16664940,
    16634476,
    54,
    54,
    30.9,
    73.4,
    12.9,
  ],
];

is_deeply $stats, $expected_stats, 'got expected stats';

#-------------------------------------------------------------------------------

# "_get_scaffold"

my @all_lane_rows = $lane_rows->all;
$lane_row = $all_lane_rows[21];
$lane_row->database($database);

$lane = Bio::Path::Find::Lane::Class::Assembly->new( row => $lane_row );
$lane->_get_scaffold;

my @all_files = $lane->all_files;
is scalar @all_files, 1, 'found one contigs.fa';
is $all_files[0]->stringify, 't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T1_OP2/SLX/APP_T1_OP2_7492533/10018_1#3/spades_assembly/contigs.fa',
  'path to contigs.fa is correct';

#---------------------------------------

# "_get_contigs"

$lane->_get_contigs;

@all_files = $lane->all_files;
is scalar @all_files, 2, 'found one contigs.fa, one unscaffolded_contigs.fa';
is $all_files[1]->stringify, 't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T1_OP2/SLX/APP_T1_OP2_7492533/10018_1#3/spades_assembly/unscaffolded_contigs.fa',
  'path to unscaffolded_contigs.fa is correct';

$lane->clear_files;

#---------------------------------------

# "_get_all"

$lane->_get_all;

@all_files = $lane->all_files;
is scalar @all_files, 2, 'found one contigs.fa, one unscaffolded_contigs.fa';

is $all_files[0]->stringify, 't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T1_OP2/SLX/APP_T1_OP2_7492533/10018_1#3/spades_assembly/contigs.fa',
  'path to contigs.fa is correct';
is $all_files[1]->stringify, 't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T1_OP2/SLX/APP_T1_OP2_7492533/10018_1#3/spades_assembly/unscaffolded_contigs.fa',
  'path to unscaffolded_contigs.fa is correct';

#-------------------------------------------------------------------------------

# done_testing;

