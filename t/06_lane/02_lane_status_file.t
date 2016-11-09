
use strict;
use warnings;

use Test::More tests => 15;
use Test::Exception;
use Test::Warn;
use Path::Class;
use File::Temp qw( tempdir );
use File::Copy 'cp';

use_ok('Bio::Path::Find::Lane::StatusFile');

throws_ok { Bio::Path::Find::Lane::StatusFile->new( status_file => file('non-existent-file') ) }
  qr/can't find status file/,
  'exception when status file is not found';

warning_like { Bio::Path::Find::Lane::StatusFile->new( status_file => file( qw( t data 06_lane 02_lane_status_file bad.txt ) ) ) }
  qr/not a valid job status file/,
  'warning with bad status file';

my $s;
lives_ok { $s = Bio::Path::Find::Lane::StatusFile->new( status_file => file( qw( t data 06_lane 02_lane_status_file good.txt ) ) ) }
  'no exception with valid status file';

is $s->config_file, 't/data/06_lane/02_lane_status_file/stored/stored_global.conf', 'config file correct';
is $s->number_of_attempts, 3, 'number of attempts correct';
is $s->current_status, 'failed', 'status correct';
is $s->number_of_attempts, 3,'number of attempts correct';

is $s->pipeline_name, 'stored', 'pipeline_name correct';

lives_ok { $s = Bio::Path::Find::Lane::StatusFile->new( status_file => file( qw( t data 06_lane 02_lane_status_file missing_config_file.txt ) ) ) }
  'no exception with status file having not-found config';
is $s->config_file, 'non-existent-file', 'non-existent config file name is returned';
is $s->number_of_attempts, 3, 'number of attempts still read correctly';

lives_ok { $s = Bio::Path::Find::Lane::StatusFile->new( status_file => file( qw( t data 06_lane 02_lane_status_file unknown_pipeline_name.txt ) ) ) }
  'no exception with status file pointing at new, unknown pipeline config';
is $s->config_file, file( qw( t data 06_lane 02_lane_status_file new_pipeline.conf ) ), 'config file is correct';

# see what happens when we try to read a file when we don't have read
# permissions on it
my $tempdir = tempdir;
my $from = file( qw( t data 06_lane 02_lane_status_file no_read_permissions.txt ) );
my $to   = file( $tempdir, 'no_read_permissions.txt' );
cp $from, $to;
chmod 0220, $to;

ok Bio::Path::Find::Lane::StatusFile->new( status_file => $to ) ;


# done_testing;

