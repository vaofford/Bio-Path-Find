
use strict;
use warnings;

use Test::More tests => 16;
use Test::Exception;
use Test::Output;
use Path::Class;

# initialise l4p to avoid warnings
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init( $FATAL );

# set up the "linked" directory for the test suite
use lib 't';

use Test::Setup;

unless ( -d dir( qw( t data linked ) ) ) {
  diag 'creating symlink directory';
  Test::Setup::make_symlinks;
}

use_ok('Bio::Path::Find::Finder');

my $config = {
  db_root           => 't/data/linked',
  connection_params => {
    tracking => {
      driver       => 'SQLite',
      dbname       => 't/data/pathogen_prok_track.db',
      schema_class => 'Bio::Track::Schema',
    },
  },
};

#---------------------------------------

# check the behaviour of the lane_role attribute

my $f;
lives_ok { $f = Bio::Path::Find::Finder->new( config => $config ) }
  'got a finder';

# first, we shouldn't have a value for lane_role because it's not specified in
# the config and this script doesn't appear in the default mapping in the class
# itself
is $f->lane_role, undef, 'lane role undef';

# next, we should get back the name of a lane_role when we hand it to the
# constructor
lives_ok { $f = Bio::Path::Find::Finder->new( config => $config, lane_role => 'my_role' ) }
  'got a finder while specifying lane_role';

is $f->lane_role, 'my_role', 'got expected value for lane_role';

# check that we get an exception from Moose when we try to apply that role but
# it doesn't exist
throws_ok { $f->find_lanes( ids => [ '10263_4' ], type => 'lane' ) }
  qr/couldn't apply role "my_role"/,
  'exception when lane_role specifies non-existent Role';

# check that we can set the name of the role correctly using lane_role
$f = Bio::Path::Find::Finder->new(
  config_file => file( qw( t data 07_finder test.conf ) ),
  lane_role   => 'Bio::Path::Find::Lane::Role::Data',
);

my $lanes;
lives_ok { $lanes = $f->find_lanes( ids => [ '10263_4' ], type => 'lane' ) }
  'no exception getting lanes when valid lane_role specified';

ok $lanes->[0]->does('Bio::Path::Find::Lane::Role::Data'),
  'correct role applied to found lanes';

#---------------------------------------

# check the behaviour of the lane_roles section of the config

# first, let's see if we can look up the Role to apply using the name of the
# calling script. We set the name of the command class to one that we know
# exists in the default script name-to-Role name mapping that's hard coded into
# the class
$f = Bio::Path::Find::Finder->new(
  config    => $config,
  lane_role => 'Bio::Path::Find::Lane::Role::Data',
);

lives_ok { $lanes = $f->find_lanes( ids => [ '10263_4' ], type => 'lane' ) }
  'no exception getting lanes when script named in default lane_roles';

ok $lanes->[0]->does('Bio::Path::Find::Lane::Role::Data'),
  'correct role applied to lanes';

# and make sure that we don't have any problems when we don't have
# a Role to apply
$f = Bio::Path::Find::Finder->new(
  config    => $config,
);

lives_ok { $lanes = $f->find_lanes( ids => [ '10263_4' ], type => 'lane' ) }
  'no exception getting lanes when script not named in default lane_roles';

ok ! $lanes->[0]->does('Bio::Path::Find::Lane::Role::Data'),
  'no roles applied to lanes';

#---------------------------------------

# make sure the finding works as expected

is scalar @$lanes, 87, 'found 87 lanes with ID 10263_4';

# check we can filter by QC status
$lanes = $f->find_lanes(
  ids  => [ '10263_4' ],
  type => 'lane',
  qc   => 'failed',
);

is scalar @$lanes, 76, 'found 76 failed lanes with ID 10263_4';

# look for lanes from a given study and check there's no progress bar
stdout_is { $lanes = $f->find_lanes( ids  => [ 607 ], type => 'study' ) }
  '',
  'no progress bar shown';

is scalar @$lanes, 50, 'found 50 lanes in study 607';

# done_testing;

