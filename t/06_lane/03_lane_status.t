
use strict;
use warnings;

use Test::More tests => 20;
use Test::Exception;
use Test::Warn;
use Path::Class;

use Log::Log4perl qw( :easy );

# set up the "linked" directory for the test suite
use lib 't';

use Test::Setup;

unless ( -d dir( qw( t data linked ) ) ) {
  diag 'creating symlink directory';
  Test::Setup::make_symlinks;
}
use_ok('Bio::Path::Find::DatabaseManager');

# initialise l4p to avoid warnings
Log::Log4perl->easy_init( $FATAL );

#---------------------------------------

# get a lane object to play with
use Bio::Path::Find::Lane;
use Bio::Path::Find::DatabaseManager;

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

my $database     = $dbm->get_database('pathogen_prok_track');
my $lane_rows_rs = $database->schema->get_lanes_by_id('10018_1', 'lane');
my @lane_rows    = $lane_rows_rs->all;

my $lane_row = $lane_rows[0];
$lane_row->database($database);

my $lane = Bio::Path::Find::Lane->new( row => $lane_row );

# quick check that the lane has the state we're expecting...
is $lane_row->processed, 2063, 'lane row has expected "processed" value';

#---------------------------------------

# and now test the Lane::Status class

use_ok('Bio::Path::Find::Lane::Status');

my $lane_status;
lives_ok { $lane_status = Bio::Path::Find::Lane::Status->new( lane => $lane ) }
  'no exception when instantiating';

isa_ok $lane_status, 'Bio::Path::Find::Lane::Status', 'status object';

# the LaneStatus object is built using the following "_job_status" file:
#   t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1/_job_status
# which points to a job config file at:
#   t/data/06_lane/03_lane_status/stored/stored_global.conf

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
$lane_status = Bio::Path::Find::Lane::Status->new( lane => $lane );

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
$lane_status = Bio::Path::Find::Lane::Status->new( lane => $lane );

is $lane_status->pipeline_status('mapped'), 'Failed (01-01-2015)', 'got correct status for "mapped" pipeline';

# check exceptions when we can't read the job status file

# the _job_status file for this lane has no read permissions set
$lane_row = $lane_rows[2];
$lane_row->database($database);
$lane = Bio::Path::Find::Lane->new( row => $lane_row );

lives_ok { $lane_status = Bio::Path::Find::Lane::Status->new( lane => $lane ) }
  'no exception when getting Status object having unreadable status files';

warnings_are { $lane_status->pipeline_status('qc') } [], 'no warning getting status for QC pipeline';

my $status;
ok $status = $lane_status->pipeline_status('annotated') ;

is $status, '-', 'status is "-" when status file is unreadable';

# done_testing;

