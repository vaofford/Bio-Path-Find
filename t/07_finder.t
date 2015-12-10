
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Output;
use Path::Class;

# initialise l4p to avoid warnings
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init( $FATAL );

use_ok('Bio::Path::Find::Finder');

my $f;
lives_ok { $f = Bio::Path::Find::Finder->new(environment => 'test', config_file => 't/data/07_finder/test.conf') }
  'got a finder';

# testing the script role feature
#
# first, there should be an exception when we haven't specified a script role
# but the name of this script, which is used to determine a default, isn't found
# in the <lane_roles> mapping in the config
throws_ok { $f->find_lanes( ids => [ '10263_4' ], type => 'lane' ) }
  qr/couldn't find a lane role for the current script/,
  'exception when lane_roles not passed and script name is not found in mapping';

# now, with the real name of this script present in the <lane_roles> mapping
# in the new config, there should be no exception
$f = Bio::Path::Find::Finder->new(environment => 'test', config_file => 't/data/07_finder/test_with_lane_role.conf');

lives_ok { $f->find_lanes( ids => [ '10263_4' ], type => 'lane' ) }
  'no exception when script named in script_roles';

# next, we revert to the original config, which has only the script named
# "pathfind" in the <script_roles> mappings. We shouldn't get an exception
# provided we cheat and explicitly set the name of the script when we
# instantiate the Finder, which allows it to correctly set a default role
# using the mapping
$f = Bio::Path::Find::Finder->new(
  environment  => 'test',
  config_file  => 't/data/07_finder/test.conf',
  _script_name => 'pathfind',
);

lives_ok { $f->find_lanes( ids => [ '10263_4' ], type => 'lane' ) }
  'no exception getting default when script named in script_roles';

# check that we get an exception from Moose when we try to apply a role
# that doesn't exist
$f = Bio::Path::Find::Finder->new(
  environment => 'test',
  config_file => 't/data/07_finder/test.conf',
  lane_role   => 'Some::Non::Existent::Role',
);

throws_ok { $f->find_lanes( ids => [ '10263_4' ], type => 'lane' ) }
  qr/couldn't apply role "Some::Non::Existent::Role"/,
  'exception when script_role not passed but role does not exist';

# and finally, check that we can explicitly set the name of the role
$f = Bio::Path::Find::Finder->new(
  environment => 'test',
  config_file => 't/data/07_finder/test.conf',
  lane_role   => 'Bio::Path::Find::Lane::Role::PathFind',
);

my $lanes;
lives_ok { $lanes = $f->find_lanes( ids => [ '10263_4' ], type => 'lane' ) }
  'no exception getting default when valid Role name provided';

is scalar @$lanes, 87, 'found 87 lanes with ID 10263_4';

# filter by QC status
$lanes = $f->find_lanes(
  ids  => [ '10263_4' ],
  type => 'lane',
  qc   => 'failed',
);

is scalar @$lanes, 76, 'found 76 failed lanes with ID 10263_4';

# look for lanes from a given study and check there's no progress bar
stdout_unlike { $lanes = $f->find_lanes( ids  => [ 607 ], type => 'study' ) }
  qr/finding lanes:/,
  'no progress bar shown when no_progress_bar set true in config';

is scalar @$lanes, 50, 'found 50 lanes in study 607';

# check we can turn on progress bars
$f->config->{no_progress_bars} = 0;

stderr_like { $lanes = $f->find_lanes( ids  => [ 607 ], type => 'study' ) }
  qr/finding lanes:/,
  'progress bar shown when finding lanes';

is scalar @$lanes, 50, 'still 50 lanes in study 607';

done_testing;

