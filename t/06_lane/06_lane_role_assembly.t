
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

use_ok('Bio::Path::Find::Lane');

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
my $lane_rows = $database->schema->get_lanes_by_id('10018_1', 'lane');

my $lane_row = $lane_rows->first;
$lane_row->database($database);

#---------------------------------------

# get a Lane, with Role applied

my $lane;

lives_ok { $lane = Bio::Path::Find::Lane->with_traits('Bio::Path::Find::Lane::Role::Assembly')
                                        ->new( row => $lane_row ) }
  'no exception when creating Lane with Assembly Role applied';

ok $lane->does('Bio::Path::Find::Lane::Role::Stats'), 'lane has Stats Role applied';
ok $lane->does('Bio::Path::Find::Lane::Role::Assembly'), 'lane has Assembly Role applied';

#-------------------------------------------------------------------------------

# check methods for retrieving or calculating stats values

# stats file parsing

my $stats;
lives_ok { $stats = $lane->_parse_stats_file( file( qw( t data 06_lane 06_lane_role_assembly spades_assembly contigs.fa.stats ) ) ) }
  'no exception when parsing assembly stats file';

my $expected_stats = {
  average_contig_length => 80.42,
  largest_contig        => 408,
  n_count               => 0,
  num_contigs           => 36,
  N50                   => 73,
  N50_n                 => 12,
  N60                   => 70,
  N60_n                 => 16,
  N70                   => 66,
  N70_n                 => 20,
  N80                   => 62,
  N80_n                 => 25,
  N90                   => 48,
  N90_n                 => 30,
  N100                  => 46,
  N100_n                => 36,
  total_length          => 2895,
};

is_deeply $stats, $expected_stats, 'parsed expected stats from file';

lives_ok { $stats = $lane->_parse_stats_file( file( qw( t data 06_lane 06_lane_role_assembly spades_assembly broken_contigs.fa.stats ) ) ) }
  'no exception when parsing "broken" assembly stats file';

$expected_stats = {
  average_contig_length => 80.42,
  largest_contig        => 408,
  n_count               => 0,
  num_contigs           => 36,
  N50                   => 73,
  N50_n                 => 12,
  N60                   => 70,
  N60_n                 => 16,
  N80                   => 62,
  N80_n                 => 25,
  N90                   => 48,
  N90_n                 => 30,
  total_length          => 2895,
};

is_deeply $stats, $expected_stats, 'parsed expected stats from broken file';

#---------------------------------------

# bamcheck file parsing

lives_ok { $stats = $lane->_parse_bc_file( file( qw( t data 06_lane 06_lane_role_assembly spades_assembly contigs.mapped.sorted.bam.bc ) ) ) }
  'no exception when parsing bamcheck file';

$expected_stats = {
  '1st fragments'                  => 304667,
  'average length'                 => 54,
  'average quality'                => 30.9,
  'bases duplicated'               => 0,
  'bases mapped'                   => 16664940,
  'bases mapped (cigar)'           => 16634476,
  'bases trimmed'                  => 0,
  'error rate'                     => '6.159557e-03',
  'filtered sequences'             => 0,
  'insert size average'            => 73.4,
  'insert size standard deviation' => 12.9,
  'inward oriented pairs'          => 29112,
  'is paired'                      => 1,
  'is sorted'                      => 1,
  'last fragments'                 => 304667,
  'maximum length'                 => 54,
  'mismatches'                     => 102461,
  'non-primary alignments'         => 0,
  'outward oriented pairs'         => 111,
  'pairs on different chromosomes' => 13108,
  'pairs with other orientation'   => 6361,
  'raw total sequences'            => 609334,
  'reads duplicated'               => 0,
  'reads mapped'                   => 308610,
  'reads MQ0'                      => 32238,
  'reads paired'                   => 97634,
  'reads QC failed'                => 0,
  'reads unmapped'                 => 300724,
  'reads unpaired'                 => 210976,
  'sequences'                      => 609334,
  'total length'                   => 32904036,
};

is_deeply $stats, $expected_stats, 'parsed expected stats from bamcheck file';

lives_ok { $stats = $lane->_parse_bc_file( file( qw( t data 06_lane 06_lane_role_assembly spades_assembly broken.bc ) ) ) }
  'no exception when parsing broken bamcheck file';

$expected_stats = {
  'fake field'                     => 'blah',
  '1st fragments'                  => 304667,
  'average length'                 => 54,
  'average quality'                => 30.9,
  'bases duplicated'               => 0,
  'bases mapped'                   => 16664940,
  'bases mapped (cigar)'           => 16634476,
  'bases trimmed'                  => 0,
  'error rate'                     => '6.159557e-03',
  'filtered sequences'             => 0,
  'insert size average'            => 73.4,
  'insert size standard deviation' => 12.9,
  'inward oriented pairs'          => 29112,
  'is paired'                      => 1,
  'is sorted'                      => 1,
  'last fragments'                 => 304667,
  'maximum length'                 => 54,
  'mismatches'                     => 102461,
  'non-primary alignments'         => 0,
  'outward oriented pairs'         => 111,
  'pairs on different chromosomes' => 13108,
  'pairs with other orientation'   => 6361,
  # removed  'raw total sequences'            => 609334,
  'reads duplicated'               => 0,
  'reads mapped'                   => 308610,
  'reads MQ0'                      => 32238,
  'reads paired'                   => 97634,
  'reads QC failed'                => 0,
  'reads unmapped'                 => 300724,
  'reads unpaired'                 => 210976,
  'sequences'                      => 609334,
  'total length'                   => 32904036,
};

is_deeply $stats, $expected_stats, 'parsed expected stats from bamcheck file';

#---------------------------------------

# "_get_assembly_type"

my $assembly_type;

# simple spades assembly
lives_ok { $assembly_type = $lane->_get_assembly_type( dir( qw( t data 06_lane 06_lane_role_assembly spades_assembly ) ), 'unscaffolded_contigs.fa.stats') }
  'no exception when getting assembly type string for unscaffolded contigs';

is $assembly_type, 'Contig: Correction, Normalisation, Primer Removal + SPAdes + Improvement',
  'got expected assembly type string';

# switch to scaffold
lives_ok { $assembly_type = $lane->_get_assembly_type( dir( qw( t data 06_lane 06_lane_role_assembly spades_assembly ) ), 'contigs.fa.stats') }
  'no exception when getting assembly type string for scaffold';

is $assembly_type, 'Scaffold: Correction, Normalisation, Primer Removal + SPAdes + Improvement',
  'got expected assembly type string';

# check the behaviour when there's no "pipeline_version"*" file
lives_ok { $assembly_type = $lane->_get_assembly_type( dir( qw( t data ) ), 'contigs.fa.stats') }
  'no exception when trying to get assembly type string';

is $assembly_type, undef, 'assembly type string undef with no pipeline_version_* file';

# change the version number of the pipeline
lives_ok { $assembly_type = $lane->_get_assembly_type( dir( qw( t data 06_lane 06_lane_role_assembly different_pipeline ) ), 'contigs.fa.stats') }
  'no exception when getting assembly type string';

is $assembly_type, 'Scaffold: Correction + Velvet + Improvement',
  'got correct assembly type with different pipeline version';

#---------------------------------------

# "_get_stats_row"

lives_ok { $stats = $lane->_get_stats_row( 'spades', 'contigs.fa.stats') }
  'no exception when getting stats row for spades';

$expected_stats = [
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
];

is_deeply $stats, $expected_stats, 'got expected stats';

#-------------------------------------------------------------------------------
#
# the Role also includes three methods, "_get_scaffold", "_get_contigs", and
# "_get_all", which aren't tested here. They're exercised by the tests for the
# command class, Bio::Path::Find::App::PathFind::Assembly.
#
#-------------------------------------------------------------------------------

# done_testing;

