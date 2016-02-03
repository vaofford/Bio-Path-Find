
use strict;
use warnings;

use Test::More tests => 27;
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
my $lane_rows = $database->schema->get_lanes_by_id('10018_1', 'lane');

my $lane_row = $lane_rows->first;
$lane_row->database($database);

#---------------------------------------

# get a Lane

my $lane;

lives_ok { $lane = Bio::Path::Find::Lane::Class::Data->new( row => $lane_row ) }
  'no exception when creating B::P::F::Lane::Class::Data';

ok $lane->does('Bio::Path::Find::Lane::Role::Stats'), 'lane has Stats Role applied';

#-------------------------------------------------------------------------------

# check methods for retrieving or calculating stats values

# "_map_type"

is $lane->_map_type, 'QC', 'map type is correct, as per the starting test data';

$lane->_tables->{mapstats}->is_qc(0);
is $lane->_map_type, 'Mapping', 'map type is correct, as per altered test data';
$lane->_tables->{mapstats}->is_qc(1);

#---------------------------------------

# "_depth_of_coverage" and "_depth_of_coverage_sd"

# calculated value for first lane
is $lane->_depth_of_coverage, '0.00', 'calculated depth of field is correct';

# mess with internal parameters a bit
my $old_mtc = $lane->_tables->{mapstats}->mean_target_coverage;
$lane->_tables->{mapstats}->mean_target_coverage(undef);

my $old_rbm = $lane->_tables->{mapstats}->rmdup_bases_mapped;
$lane->_tables->{mapstats}->rmdup_bases_mapped(100000);

is $lane->_depth_of_coverage, '0.05',
  'calculated depth of field is correct (messed with "rmdup_bases_mapped")';

my $old_qb = $lane->_tables->{mapstats}->raw_bases;
$lane->_tables->{mapstats}->raw_bases($old_qb/2);

is $lane->_depth_of_coverage, '0.10',
  'calculated depth of field is correct (messed with "raw_bases")';

is $lane->_depth_of_coverage_sd, '0.02',
  'calculated depth of field is correct (with tweaked params in "_depth_of_coverage")';

# reset the tweaked values
$lane->_tables->{mapstats}->mean_target_coverage($old_mtc);
$lane->_tables->{mapstats}->rmdup_bases_mapped($old_rbm);
$lane->_tables->{mapstats}->raw_bases($old_qb);

is $lane->_depth_of_coverage_sd, '0.01',
  'calculated depth of field is correct (with reset params)';

#---------------------------------------

# "_adapter_percentage"

is $lane->_adapter_percentage, '2.3', 'calculated adapter percentage correctly';

$lane->_tables->{mapstats}->is_qc(0);
is $lane->_adapter_percentage, 'NA',
  'refused to calculate adapter percentage ("is_qc" set to zero)';
$lane->_tables->{mapstats}->is_qc(1);

my $old_ar = $lane->_tables->{mapstats}->adapter_reads;
$lane->_tables->{mapstats}->adapter_reads($old_ar * 2);

is $lane->_adapter_percentage, '4.7',
  'calculated adapter percentage correctly (doubled adapter reads)';

$lane->_tables->{mapstats}->adapter_reads($old_ar);

#---------------------------------------

# "_transposon_percentage"

is $lane->_transposon_percentage, '90.2', 'returned transposon percentage correctly';

$lane->_tables->{mapstats}->is_qc(0);
is $lane->_transposon_percentage, 'NA',
  'refused to return transposon percentage ("is_qc" set to zero)';
$lane->_tables->{mapstats}->is_qc(1);

my $old_prwt = $lane->_tables->{mapstats}->percentage_reads_with_transposon;
$lane->_tables->{mapstats}->percentage_reads_with_transposon($old_prwt/2);

is $lane->_transposon_percentage, '45.1',
  'calculated transposon percentage (halved "percentage_reads_with_transposon")';

#---------------------------------------

# "_genome_covered"

is $lane->_genome_covered, '0.00', 'returned genome coverage percentage correctly';

my $old_tbm = $lane->_tables->{mapstats}->target_bases_mapped;
$lane->_tables->{mapstats}->target_bases_mapped(100000);
is $lane->_genome_covered, '4.98',
  'returned genome coverage percentage correctly (doubled "target_bases_mapped")';

$lane->_tables->{mapstats}->target_bases_mapped(undef);

is $lane->_genome_covered, 'NA',
  'refused to return genome coverage ("target_bases_mapped" set to undef)';

$lane->_tables->{mapstats}->target_bases_mapped(47);

#---------------------------------------

# "_duplication_rate"

is $lane->_duplication_rate, '0.0000', 'returned duplication rate correctly';

my $old_rrm = $lane->_tables->{mapstats}->rmdup_reads_mapped;
my $old_rm  = $lane->_tables->{mapstats}->reads_mapped;

$lane->_tables->{mapstats}->rmdup_reads_mapped(undef);

is $lane->_duplication_rate, 'NA',
  'refused to return duplication rate ("rmdup_reads_mapped" set to undef)';

$lane->_tables->{mapstats}->rmdup_reads_mapped(10);
$lane->_tables->{mapstats}->reads_mapped(100);

is $lane->_duplication_rate, '0.9000', 'returned duplication rate correctly';

#---------------------------------------

# "_error_rate"

is $lane->_error_rate, '0.044', 'returned error rate correctly';

$lane->_tables->{mapstats}->is_qc(0);

is $lane->_error_rate, 'NA', 'refused to return error rate ("is_qc" false)';

$lane->_tables->{mapstats}->is_qc(1);


#---------------------------------------

# "het_snp_stats"

my $expected_het_snp_stats = [
  1,
  2.0868283360403e-05,
  0.0112145340361108,
  3.57142857142857,
];

is_deeply [ $lane->_het_snp_stats ], $expected_het_snp_stats, 'returned het SNP stats correctly';

$lane->row->hierarchy_name('non-existent');

is_deeply [ $lane->_het_snp_stats ], [ qw( NA NA NA NA ) ], 'returned "NA" for het SNP stats (missing file)';

#---------------------------------------

# done_testing;

