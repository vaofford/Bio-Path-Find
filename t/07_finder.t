
use strict;
use warnings;

use Test::More tests => 13;
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

# needed here to make sure this class is loaded before we try to instantiate
# the finder
use Bio::Path::Find::Lane::Class::Data;

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

# check the behaviour of the lane_class attribute

my $f;
lives_ok { $f = Bio::Path::Find::Finder->new( config => $config ) }
  'got a finder';

# first, the default value
isa_ok $f->lane_class, 'Bio::Path::Find::Lane';

throws_ok { $f = Bio::Path::Find::Finder->new( config => $config, lane_class => 'my_class' ) }
  qr/does not pass the type constraint/,
  'exception when trying to use non-existent lane class';

# check that we can set the name of the role correctly using lane_class
$f = Bio::Path::Find::Finder->new(
  config     => $config,
  lane_class => 'Bio::Path::Find::Lane::Class::Data',
);

my $lanes;
lives_ok { $lanes = $f->find_lanes( ids => [ '10263_4' ], type => 'lane' ) }
  'no exception getting lanes when valid lane_class specified';

isa_ok $lanes->[0], 'Bio::Path::Find::Lane::Class::Data';
ok $lanes->[0]->does('Bio::Path::Find::Lane::Role::Stats'), 'Stats Role applied to Lane';

#---------------------------------------

# make sure that we don't have any problems when we don't name a specific class
$f = Bio::Path::Find::Finder->new( config => $config );

lives_ok { $lanes = $f->find_lanes( ids => [ '10263_4' ], type => 'lane' ) }
  'no exception getting lanes when script not named in default lane_roles';

isa_ok $lanes->[0], 'Bio::Path::Find::Lane';

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

