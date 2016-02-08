
# a dummy Role that provides the two required methods for the Stats Role.

package TestRole;

use Moose::Role;

with 'Bio::Path::Find::Lane::Role::Stats';

sub _build_stats_headers {
  [ 'one', 'two' ];
}

sub _build_stats {
  [ [ 1, 2, ] ];
}

#-------------------------------------------------------------------------------

package main;

use strict;
use warnings;

use Test::More tests => 55;
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
my $lane_rows = $database->schema->get_lanes_by_id('10018_1', 'lane');

my $lane_row = $lane_rows->first;
$lane_row->database($database);

#---------------------------------------

# get a Lane, with Role applied

my $lane;

lives_ok { $lane = Bio::Path::Find::Lane->with_traits('TestRole')
                                        ->new( row => $lane_row ) }
  'no exception when creating Lane with Stats Role applied';

ok $lane->does('Bio::Path::Find::Lane::Role::Stats'), 'lane has Stats Role applied';

# make sure the overridden methods work
my $expected_headers = [ qw( one two ) ];
my $expected_stats   = [ [ 1, 2 ] ];

is_deeply $lane->stats_headers, $expected_headers, 'got expected headers';
is_deeply $lane->stats,         $expected_stats,   'got expected stats';

# check we get back the tables we expect, as the right sort of objects
isa_ok $lane->_tables->{lane},     'Bio::Track::Schema::Result::LatestLane',    'lane from "_tables"';
isa_ok $lane->_tables->{library},  'Bio::Track::Schema::Result::LatestLibrary', 'library from "_tables"';
isa_ok $lane->_tables->{sample},   'Bio::Track::Schema::Result::LatestSample',  'sample from "_tables"';
isa_ok $lane->_tables->{project},  'Bio::Track::Schema::Result::LatestProject', 'project from "_tables"';
isa_ok $lane->_tables->{mapstats}, 'Bio::Track::Schema::Result::LatestMapstat', 'mapstats from "_tables"';
isa_ok $lane->_tables->{assembly}, 'Bio::Track::Schema::Result::Assembly',      'assembly from "_tables"';
isa_ok $lane->_tables->{mapper},   'Bio::Track::Schema::Result::Mapper',        'mapper from "_tables"';

#-------------------------------------------------------------------------------

# check the utility methods

# "_mapping_is_complete" and "_is_mapped"

my $mapstats_table = $lane->_tables->{mapstats};

ok $lane->_mapping_is_complete, '"_mapping_is_complete" returns 1 with starting test data';
ok $lane->_is_mapped, '"_is_mapped" returns 1 with starting data';

$lane->_tables->{mapstats} = undef;
ok ! $lane->_mapping_is_complete, '"_mapping_is_complete" returns 0 with no mapstats data';
ok ! $lane->_is_mapped, '"_is_mapped" returns 0 when "mapstats" table is undef';

$mapstats_table->bases_mapped(0);
$lane->_tables->{mapstats} = $mapstats_table;
ok ! $lane->_mapping_is_complete, '"_mapping_is_complete" returns 0 when no bases mapped';
ok ! $lane->_is_mapped, '"_is_mapped" returns 0 when "_is_mapped" is false';

$mapstats_table->bases_mapped(846);
$lane->_tables->{mapstats}->is_qc(0);
ok ! $lane->_is_mapped, '"_is_mapped" returns 0 when "_is_qc" is false';

$lane->_tables->{mapstats}->is_qc(1);

#---------------------------------------

# "_trim"

is $lane->_trim('word'), 'word', '"_trim" does not change string without surrounding spaces';
is $lane->_trim('wo rd'), 'wo rd', '"_trim" does not change string with internal spaces';

is $lane->_trim(' word'), 'word', '"_trim" trims leading space';
is $lane->_trim('  word'), 'word', '"_trim" trims multiple leading spaces';
is $lane->_trim('	word'), 'word', '"_trim" trims leading tab';
is $lane->_trim('		word'), 'word', '"_trim" trims multiple leading tabs';

is $lane->_trim('word '), 'word', '"_trim" trims trailing space';
is $lane->_trim('word  '), 'word', '"_trim" trims multiple trailing spaces';
is $lane->_trim('word	'), 'word', '"_trim" trims trailing tab';
is $lane->_trim('word		'), 'word', '"_trim" trims multiple trailing tabs';

is $lane->_trim(' word '), 'word', '"_trim" trims wrapping space';
is $lane->_trim('  word  '), 'word', '"_trim" trims multiple wrapping spaces';
is $lane->_trim('	word	'), 'word', '"_trim" trims wrapping tab';
is $lane->_trim('	word		'), 'word', '"_trim" trims multiple wrapping tabs';

#---------------------------------------

# "_trimf"

is $lane->_trimf('word'), 'word', '"_trimf" leaves non-numeric string untouched';
is $lane->_trimf(' word'), 'word', '"_trimf" trims non-numeric string';
is $lane->_trimf(' 1'), '1.00', '"_trimf" trims single digit';
is $lane->_trimf(' 123  '), '123.00', '"_trimf" trims three digit integer';
is $lane->_trimf(' 123.321  '), '123.32', '"_trimf" trims float';
is $lane->_trimf(' 123.456  '), '123.46', '"_trimf" rounds and trims float';
is $lane->_trimf(' 123.456789  ', '%09.3f'), '00123.457', '"_trimf" works with valid format';
is $lane->_trimf(' 123.456789 ', '% 9.2f'), '   123.46', '"_trimf" returns correctly when format adds leading spaces';

#---------------------------------------

# "_percentage"

is $lane->_percentage('word'), 'NaN', '"_percentage" returns "NaN" for single value, a non-numeric string';
is $lane->_percentage('word',1), 'NaN', '"_percentage" returns "NaN" for non-numeric string';
is $lane->_percentage(1), 'NaN', '"_percentage" returns "NaN" with single numeric argument';
is $lane->_percentage(1, 10), '10.0', '"_percentage" returns correct value for integer args';
is $lane->_percentage(1, 10, '%5.2f'), '10.00', '"_percentage" returns correct when format given';

#---------------------------------------

# stats file parsing

my $stats;
lives_ok { $stats = $lane->_parse_stats_file( file( qw( t data 06_lane 04_lane_role_stats spades_assembly contigs.fa.stats ) ) ) }
  'no exception when parsing assembly stats file';

$expected_stats = {
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

# done_testing;

