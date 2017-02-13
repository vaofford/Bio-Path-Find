
use strict;
use warnings;

use Test::More tests => 14;
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
my $lane_rows = $database->schema->get_lanes_by_id(['10018_1'], 'lane');

my $lane_row = $lane_rows->first;
$lane_row->database($database);

#---------------------------------------

# get a Lane, with Role applied

my $lane;

lives_ok { $lane = Bio::Path::Find::Lane->with_traits('Bio::Path::Find::Lane::Role::HasAssembly')
                                        ->new( row => $lane_row ) }
  'no exception when creating Lane with HasAssembly Role applied';

ok $lane->does('Bio::Path::Find::Lane::Role::HasAssembly'), 'lane has HasAssembly Role applied';

#---------------------------------------

# check pipeline_versions, making sure we can override the mapping by
# putting it in the config

# this should come from the Role itself
my $got_pv = $lane->_pipeline_versions;

my $expected_pv = {
  '2.0.0' => 'Velvet',
  '2.0.1' => 'Velvet + Improvement',
  '2.1.0' => 'Correction, Normalisation, Primer Removal + Velvet',
  '2.1.1' => 'Correction, Normalisation, Primer Removal + Velvet + Improvement',
  '2.2.0' => 'Correction, Normalisation + Velvet',
  '2.2.1' => 'Correction, Normalisation + Velvet + Improvement',
  '2.3.0' => 'Correction, Primer Removal + Velvet',
  '2.3.1' => 'Correction, Primer Removal + Velvet + Improvement',
  '2.4.0' => 'Normalisation, Primer Removal + Velvet',
  '2.4.1' => 'Normalisation, Primer Removal + Velvet + Improvement',
  '2.5.0' => 'Correction + Velvet',
  '2.5.1' => 'Correction + Velvet + Improvement',
  '2.6.0' => 'Normalisation + Velvet',
  '2.6.1' => 'Normalisation + Velvet + Improvement',
  '2.7.0' => 'Primer Removal + Velvet',
  '2.7.1' => 'Primer Removal + Velvet + Improvement',
  '3.0.0' => 'SPAdes',
  '3.0.1' => 'SPAdes + Improvement',
  '3.1.0' => 'Correction, Normalisation, Primer Removal + SPAdes',
  '3.1.1' => 'Correction, Normalisation, Primer Removal + SPAdes + Improvement',
  '3.2.0' => 'Correction, Normalisation + SPAdes',
  '3.2.1' => 'Correction, Normalisation + SPAdes + Improvement',
  '3.3.0' => 'Correction, Primer Removal + SPAdes',
  '3.3.1' => 'Correction, Primer Removal + SPAdes + Improvement',
  '3.4.0' => 'Normalisation, Primer Removal + SPAdes',
  '3.4.1' => 'Normalisation, Primer Removal + SPAdes + Improvement',
  '3.5.0' => 'Correction + SPAdes',
  '3.5.1' => 'Correction + SPAdes + Improvement',
  '3.6.0' => 'Normalisation + SPAdes',
  '3.6.1' => 'Normalisation + SPAdes + Improvement',
  '3.7.0' => 'Primer Removal + SPAdes',
  '3.7.1' => 'Primer Removal + SPAdes + Improvement',
  '5.0.0' => 'IVA',
  '5.0.1' => 'IVA + Improvement',
  '5.1.0' => 'Correction, Normalisation, Primer Removal + IVA',
  '5.1.1' => 'Correction, Normalisation, Primer Removal + IVA + Improvement',
  '5.2.0' => 'Correction, Normalisation + IVA',
  '5.2.1' => 'Correction, Normalisation + IVA + Improvement',
  '5.3.0' => 'Correction, Primer Removal + IVA',
  '5.3.1' => 'Correction, Primer Removal + IVA + Improvement',
  '5.4.0' => 'Normalisation, Primer Removal + IVA',
  '5.4.1' => 'Normalisation, Primer Removal + IVA + Improvement',
  '5.5.0' => 'Correction + IVA',
  '5.5.1' => 'Correction + IVA + Improvement',
  '5.6.0' => 'Normalisation + IVA',
  '5.6.1' => 'Normalisation + IVA + Improvement',
  '5.7.0' => 'Primer Removal + IVA',
  '5.7.1' => 'Primer Removal + IVA + Improvement',
  '2'     => 'Velvet + Improvement',
  '2.1'   => 'Velvet + Improvement',
  '3'     => 'Correction, Normalisation, Primer Removal + SPAdes + Improvement',
  '3.1'   => 'Correction, Normalisation, Primer Removal + Velvet + Improvement',
  '3.2'   => 'Normalisation + SPAdes + Improvement',
  '4'     => 'Correction + Velvet + Improvement',
  '5'     => 'IVA',
  '6.0'   => 'SMRT analysis 2.2.0'
};

is_deeply $got_pv, $expected_pv, 'got expected pipeline version mapping from assembly Role';

$config->{pipeline_versions} = {
  '1.0.0' => 'Assembler',
  '2.0.0' => 'Different assembler',
};

$lane->clear_config;

$lane = Bio::Path::Find::Lane->with_traits('Bio::Path::Find::Lane::Role::HasAssembly')
                             ->new( config => $config, row => $lane_row );

$got_pv = $lane->_pipeline_versions;
$expected_pv = {
  '1.0.0' => 'Assembler',
  '2.0.0' => 'Different assembler',
};

is_deeply $got_pv, $expected_pv, 'got expected pipeline version mapping from config';

#---------------------------------------

# stats file parsing

my $stats;
lives_ok { $stats = $lane->_parse_stats_file( file( qw( t data 06_lane 04_lane_role_stats spades_assembly contigs.fa.stats ) ) ) }
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

lives_ok { $stats = $lane->_parse_stats_file( file( qw( t data 06_lane 04_lane_role_stats spades_assembly broken_contigs.fa.stats ) ) ) }
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

lives_ok { $stats = $lane->_parse_bc_file( file( qw( t data 06_lane 04_lane_role_stats spades_assembly contigs.mapped.sorted.bam.bc ) ) ) }
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

lives_ok { $stats = $lane->_parse_bc_file( file( qw( t data 06_lane 04_lane_role_stats spades_assembly broken.bc ) ) ) }
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

# TODO _parse_gff_file

#---------------------------------------

# TODO _get_assembly_type

#---------------------------------------

# done_testing;

