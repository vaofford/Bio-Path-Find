
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Path::Class;

use Log::Log4perl qw( :easy );

# initialise l4p to avoid warnings
Log::Log4perl->easy_init( $FATAL );

# get a lane object to play with
use Bio::Path::Find::Lane;
use Bio::Path::Find::DatabaseManager;

my $dbm = Bio::Path::Find::DatabaseManager->new(
  environment => 'test',
  config_file => 't/data/10_lane_status/test.conf',
);

my $database     = $dbm->get_database('pathogen_prok_track');
my $lane_rows_rs = $database->schema->get_lanes_by_id('10018_1', 'lane');
my @lane_rows    = $lane_rows_rs->all;

my $lane_row = $lane_rows[0];
$lane_row->database($database);

my $lane = Bio::Path::Find::Lane->new( row => $lane_row );

# quick check that the lane has the state we're expecting...
is $lane_row->processed, 15, 'lane row has expected "processed" value';

# and now test the LaneStatus class

use_ok('Bio::Path::Find::LaneStatus');

my $lane_status;
lives_ok { $lane_status = Bio::Path::Find::LaneStatus->new( lane => $lane ) }
  'no exception when instantiating';

isa_ok $lane_status, 'Bio::Path::Find::LaneStatus', 'status object';

ok $lane_status->has_status_files, 'loaded a status file';

my @keys = keys %{ $lane_status->status_files };
is_deeply [ 'stored' ], \@keys, 'got expected pipeline name in status_file hash';

lives_ok { $lane_status->status_files } 'no exception when finding status files';
my @pipelines = keys %{ $lane_status->status_files };
is scalar @pipelines, 1, 'got one status file';
is $pipelines[0], 'stored', 'got status file for "stored" pipeline';

is $lane_status->pipeline_status, 'NA', 'got pipeline status "NA" with no pipeline name';
is $lane_status->pipeline_status('no-such-pipeline'), 'NA', 'got pipeline status "NA" with unknown pipeline name';

# get a different lane that has two config files in its symlink directory, so
# that we can check behaviour of "pipeline_status" with multiple configs
$lane_row = $lane_rows[1];
$lane_row->database($database);
$lane = Bio::Path::Find::Lane->new( row => $lane_row );
$lane_status = Bio::Path::Find::LaneStatus->new( lane => $lane );

is $lane_status->pipeline_status('stored'), 'Done', 'got correct status for "stored" pipeline';
is $lane_status->pipeline_status('qc'),     'Done', 'got correct status for "qc" pipeline';

# set the access times for the two "mapped" status files explicitly
my $working_dir = $lane->symlink_path;
my $status_1    = file( $working_dir, '_mapped_1_job_status' ); # running
my $status_2    = file( $working_dir, '_mapped_2_job_status' ); # failed
system( "touch -t 201501010000 $status_1" );
system( "touch -t 201001010000 $status_2" );

is $lane_status->pipeline_status('mapped'), 'Running (01-01-2015)', 'got correct status for "mapped" pipeline';

# reverse the date order of the two files and check that we get a different status
system( "touch -t 201001010000 $status_1" );
system( "touch -t 201501010000 $status_2" );
$lane_status = Bio::Path::Find::LaneStatus->new( lane => $lane );

is $lane_status->pipeline_status('mapped'), 'Failed (01-01-2015)', 'got correct status for "mapped" pipeline';

done_testing;

