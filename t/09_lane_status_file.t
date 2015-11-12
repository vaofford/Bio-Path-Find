
use strict;
use warnings;

#-------------------------------------------------------------------------------

# mock a B::P::F::Lane class

package Bio::Path::Find::Lane;

use Moose;
use namespace::autoclean;

sub qc_status { 'passed' }

#-------------------------------------------------------------------------------

package main;

use Test::More;
use Test::Exception;
use Test::Warn;
use Path::Class;

use_ok('Bio::Path::Find::LaneStatusFile');

my $mock_lane = Bio::Path::Find::Lane->new;

throws_ok { Bio::Path::Find::LaneStatusFile->new( status_file => file('non-existent-file'), lane => $mock_lane ) }
  qr/can't find status file/,
  'exception when status file is not found';

warning_like { Bio::Path::Find::LaneStatusFile->new( status_file => file('t/data/09_lane_status_file/bad.txt'), lane => $mock_lane ) }
  qr/not a valid status file/,
  'warning with bad status file';

my $s;
lives_ok { $s = Bio::Path::Find::LaneStatusFile->new( status_file => file('t/data/09_lane_status_file/good.txt'), lane => $mock_lane ) }
  'no exception with valid status file';

is $s->config_file, 't/data/09_lane_status_file/stored/stored_global.conf', 'config file correct';
is $s->number_of_attempts, 3, 'number of attempts correct';
is $s->current_status, 'failed', 'status correct';
is $s->number_of_attempts, 3,' number of attempts correct';

lives_ok { $s = Bio::Path::Find::LaneStatusFile->new( status_file => file('t/data/09_lane_status_file/missing_config_file.txt'), lane => $mock_lane ) }
  'no exception with status file having not-found config';
is $s->config_file, undef, 'config file is undef';
is $s->number_of_attempts, 3, 'number of attempts still read correctly';

$DB::single = 1;

done_testing;

