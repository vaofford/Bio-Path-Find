
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Warn;
use Path::Class;

use_ok('Bio::Path::Find::Lane::StatusFile');

throws_ok { Bio::Path::Find::Lane::StatusFile->new( status_file => file('non-existent-file') ) }
  qr/can't find status file/,
  'exception when status file is not found';

warning_like { Bio::Path::Find::Lane::StatusFile->new( status_file => file('t/data/09_lane_status_file/bad.txt') ) }
  qr/not a valid status file/,
  'warning with bad status file';

my $s;
lives_ok { $s = Bio::Path::Find::Lane::StatusFile->new( status_file => file('t/data/09_lane_status_file/good.txt') ) }
  'no exception with valid status file';

is $s->config_file, 't/data/09_lane_status_file/stored/stored_global.conf', 'config file correct';
is $s->number_of_attempts, 3, 'number of attempts correct';
is $s->current_status, 'failed', 'status correct';
is $s->number_of_attempts, 3,'number of attempts correct';

is $s->pipeline_name, 'stored', 'pipeline_name correct';

lives_ok { $s = Bio::Path::Find::Lane::StatusFile->new( status_file => file('t/data/09_lane_status_file/missing_config_file.txt') ) }
  'no exception with status file having not-found config';
is $s->config_file, undef, 'config file is undef';
is $s->number_of_attempts, 3, 'number of attempts still read correctly';

warning_like { $s->pipeline_name }
  qr/no config file loaded/,
  'warning about missing config';

lives_ok { $s = Bio::Path::Find::Lane::StatusFile->new( status_file => file('t/data/09_lane_status_file/unknown_pipeline_name.txt') ) }
  'no exception with status file pointing at new, unknown pipeline config';
is $s->config_file, 't/data/09_lane_status_file/new_pipeline.conf', 'config file is correct';

warning_like { $s->pipeline_name }
  qr/unrecognised pipeline in config/,
  'warning about unrecognised config';

done_testing;

