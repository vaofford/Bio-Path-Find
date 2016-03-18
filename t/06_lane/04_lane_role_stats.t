
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

use Test::More tests => 79;
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
is ref $lane->_tables, 'HASH', 'got tables';
isa_ok $lane->_tables->{library},  'Bio::Track::Schema::Result::LatestLibrary', 'library from "_tables"';
isa_ok $lane->_tables->{sample},   'Bio::Track::Schema::Result::LatestSample',  'sample from "_tables"';
isa_ok $lane->_tables->{project},  'Bio::Track::Schema::Result::LatestProject', 'project from "_tables"';

#-------------------------------------------------------------------------------

# check the "output" methods

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

#-------------------------------------------------------------------------------

# check that we get the expected rows from the mapstats table
$lane->_clear_mapstats_rows;
$lane->use_qc_stats(1);

ok $lane->_has_mapstats_rows, 'got mapstats_rows';
is scalar @{ $lane->_mapstats_rows }, 1, 'got 1 row in mapstats_rows';
ok $lane->_mapstats_rows->[0]->is_qc, 'mapstats row is a QC mapping';

my $ms = $lane->_mapstats_rows->[0];

is $lane->_map_type($ms), 'QC', 'got QC mapping';
ok $lane->_mapping_is_complete($ms), '"_mapping_is_complete" returns true with QC mapping';

$ms->bases_mapped(0);
ok ! $lane->_mapping_is_complete($ms), '"_mapping_is_complete" returns 0 when no bases mapped for QC mapping';
$ms->bases_mapped(846);

#---------------------------------------

# make sure "use_qc_stats" does what's intended. It should make the "_mapstats_rows"
# array contain mapstats rows corresponding to real mappings, not QC mappings
$lane->_clear_mapstats_rows;
$lane->use_qc_stats(0);

ok $lane->_has_mapstats_rows, 'got mapstats_rows';
is scalar @{ $lane->_mapstats_rows }, 1, 'got 1 row in mapstats_rows';

$ms = $lane->_mapstats_rows->[0];
ok ! $ms->is_qc, 'mapstats row is a *not* a QC mapping';

is $lane->_map_type($ms), 'Mapping', 'got non-QC mapping';
ok $lane->_mapping_is_complete($ms), '"_mapping_is_complete" returns true with non-QC mapping';

$ms->bases_mapped(0);
ok ! $lane->_mapping_is_complete($ms), '"_mapping_is_complete" returns 0 when no bases mapped for QC mapping';
$ms->bases_mapped(846);

#---------------------------------------

$ms->reads_mapped(1);
$ms->raw_reads(5);
is $lane->_mapped_percentage($ms), '20.0', '"_mapped_percentage" gives expected result';
$ms->reads_mapped(4993);   # reset to original

$ms->reads_paired(1);
$ms->raw_reads(5);
is $lane->_paired_percentage($ms), '20.0', '"_paired_percentage" gives expected result';
$ms->reads_paired(0);
$ms->raw_reads(397141);

$ms->bases_mapped(0);
is $lane->_mapped_percentage($ms), '0.0', '"_mapped_percentage" gives expected result when no bases mapped';
is $lane->_paired_percentage($ms), '0.0', '"_paired_percentage" gives expected result when no bases mapped';
$ms->bases_mapped(846);

is $lane->_mapped_percentage, '0.0', '"_mapped_percentage" gives "0.0" with no mapstats row';
is $lane->_paired_percentage, '0.0', '"_paired_percentage" gives "0.0" with no mapstats row';

#---------------------------------------

is $lane->_depth_of_coverage, 'NA', '"_depth_of_coverage" gives "NA" with no mapstats row';
is $lane->_depth_of_coverage_sd, 'NA', '"_depth_of_coverage_sd" gives "NA" with no mapstats row';

# start with a non-QC mapping (mapstats row has is_qc == 0)
is $lane->_depth_of_coverage($ms), '0.10', '"_depth_of_coverage" gives expected value for non-QC mapping';
is $lane->_depth_of_coverage_sd($ms), '2.97', '"_depth_of_coverage_sd" gives expected value for non-QC mapping';

# switch to the QC mapping
$lane->_clear_mapstats_rows;
$lane->use_qc_stats(1);
$ms = $lane->_mapstats_rows->[0];

# set all of the values that are used for calculating depth of coverage
$ms->mean_target_coverage(2.00);
$ms->is_qc(0);
is $lane->_depth_of_coverage($ms), '2.00', '"_depth_of_coverage" takes value from QC mapstats row when "is_qc ==0"';
$ms->is_qc(1);

$ms->bases_mapped(0);
is $lane->_depth_of_coverage($ms), '2.00', '"_depth_of_coverage" takes value from QC mapstats row when "bases_mapped == 0"';
$ms->bases_mapped(846);

$ms->mean_target_coverage(undef);
$ms->rmdup_bases_mapped(2);
$ms->assembly->reference_size(4); # genome size
$lane->row->raw_bases(1);         # raw bases
$ms->raw_bases(2);                # qc bases
is $lane->_depth_of_coverage($ms), '0.25', '"_depth_of_coverage" calculates value correctly';

# and reset everything
$ms->mean_target_coverage(0.1);
$ms->rmdup_bases_mapped(846);
$ms->assembly->reference_size(2_007_491);
$lane->row->raw_bases(18_665_627);
$ms->raw_bases(18_665_627);

# and now standard deviation of depth of coverage
$ms->target_coverage_sd(0.1);
$lane->row->raw_bases(1);
$ms->raw_bases(2);
is $lane->_depth_of_coverage_sd($ms), '0.05', '"_depth_of_coverage_sd" gives expected value from QC mapstats row';
$ms->target_coverage_sd(0.01);
$lane->row->raw_bases(18_665_627);
$ms->raw_bases(18_665_627);

#---------------------------------------

is $lane->_adapter_percentage,    'NA', '"_adapter_percentage" returns "NA" with no mapstats row';
is $lane->_transposon_percentage, 'NA', '"_transposon_percentage" returns "NA" with no mapstats_row';

$ms->adapter_reads(1);
$ms->raw_reads(2);
is $lane->_adapter_percentage($ms), '50.0', '"_adapter_percentage" returns expected value with QC mapstats row';
$ms->adapter_reads(undef);
$ms->raw_reads(397_141);

$ms->percentage_reads_with_transposon(50);
is $lane->_transposon_percentage($ms), '50.0', '"_transposon_percentage" returns expected value with QC mapstats row';
$ms->percentage_reads_with_transposon(90.2493);

# switch to the non-QC mapping
$lane->_clear_mapstats_rows;
$lane->use_qc_stats(0);
$ms = $lane->_mapstats_rows->[0];

# should only get a value for QC mappings
is $lane->_adapter_percentage($ms),    'NA', '_adapter_percentage" returns "NA" with non-QC mapstats row';
is $lane->_transposon_percentage($ms), 'NA', '"_transposon_percentage" returns "NA" with non-QC mapstats_row';

#---------------------------------------

is $lane->_genome_covered, 'NA', '"_genome_covered" returns "NA" with no mapstats row';
is $lane->_genome_covered($ms), 'NA', '"_genome_covered" returns "NA" with non-QC mapstats row';

is $lane->_duplication_rate, 'NA', '"_duplication_rate" returns "NA" with no mapstats row';
is $lane->_duplication_rate($ms), 'NA', '"_duplication_rate" returns "NA" with non-QC mapstats row';

is $lane->_error_rate, 'NA', '"_error_rate" returns "NA" with no mapstats row';
is $lane->_error_rate($ms), 'NA', '"_error_rate" returns "NA" with non-QC mapstats row';

# switch to the QC mapping
$lane->_clear_mapstats_rows;
$lane->use_qc_stats(1);
$ms = $lane->_mapstats_rows->[0];

$ms->target_bases_mapped(1);
$ms->assembly->reference_size(2);
is $lane->_genome_covered($ms), '50.00', '"_genome_covered" returns expected value with QC mapstats row';
$ms->target_bases_mapped(47);
$ms->assembly->reference_size(2_007_491);

$ms->rmdup_reads_mapped(1);
$ms->reads_mapped(4);
is $lane->_duplication_rate($ms), '0.7500', '"_duplication_rate" returns expected value with QC mapstats row';
$ms->rmdup_reads_mapped(18);
$ms->reads_mapped(18);

$ms->error_rate(0.12);
is $lane->_error_rate($ms), '0.120', '"_error_rate" returns expected value with QC mapstats row';
$ms->error_rate(0.0437352);

#---------------------------------------

$expected_stats = [ 1, 2.0868283360403e-05, 0.0112145340361108, 3.57142857142857 ];

is_deeply [ $lane->_het_snp_stats ], $expected_stats, 'got expected values from "_het_snp_stats"';

#---------------------------------------

# done_testing;

