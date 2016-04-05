
use strict;
use warnings;

use Test::More tests => 33;
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

#-------------------------------------------------------------------------------

my $f;
lives_ok { $f = Bio::Path::Find::Finder->new( config => $config ) }
  'got a finder';

# get a lane row to play with
my $database = $f->_db_manager->get_database('pathogen_prok_track');
my $schema   = $database->schema;
my $lanes_rs = $schema->resultset('LatestLane');
my $lane_row = $lanes_rs->first;

#---------------------------------------

# check the "_create_lane" method

my $lane;
lives_ok { $f->_create_lane($lane_row) } 'no exception when creating a Lane';

is $f->_create_lane($lane_row, 4096),        undef, 'no lane when filtered on "processed"';
is $f->_create_lane($lane_row, undef, 'passed'), undef, 'no lane when filtered on QC';

$lane = $f->_create_lane($lane_row, undef, 'pending', {search_depth => 2});
ok $lane, 'got lane with no filtering';
is $lane->search_depth, 2, 'attribute correctly set on lane';

#---------------------------------------

# check "_find_lanes"

my $lanes;
lives_ok { $lanes = $f->_find_lanes( [ '10263_4' ], 'lane' ) }
  'no exception from "_find_lanes"';

is scalar @$lanes, 87, 'got expected number of lanes from "_find_lanes"';

$lanes = $f->_find_lanes( [ '10263_4' ], 'lane', undef );
is scalar @$lanes, 87, '87 lanes from "_find_lanes" when "processed" is undef';
$lanes = $f->_find_lanes( [ '10263_4' ], 'lane', 4096 );
is scalar @$lanes, 0, 'no lanes from "_find_lanes" when filtered on "processed"';
$lanes =$f->_find_lanes( [ '10263_4' ], 'lane', undef, 'passed' );
is scalar @$lanes, 0, 'no lanes from "_find_lanes" when filtered on QC status';

#---------------------------------------

# check "_find_all_lanes"

is_deeply $f->_find_all_lanes, [], '"_find_all_lanes" returns undef without IDs';
is_deeply $f->_find_all_lanes([]), [], '"_find_all_lanes" returns undef with empty IDs array';
is_deeply $f->_find_all_lanes( ['pathogen_prok_track']), [], '"_find_all_lanes" returns undef without type';
is_deeply $f->_find_all_lanes( ['pathogen_prok_track'], 'lane'), [],
  '"_find_all_lanes" returns undef with type ne "database';

stderr_like { $f->_find_all_lanes(['no_such_db'], 'database') }
  qr/^No such database \("no_such_db"\)/,
  'got "no such database" from "_find_all_lanes"';

throws_ok { $f->_find_all_lanes(['pathogen_prok_track'], 'database') }
  qr/bad thing to do/,
  'got exception from "_find_all_lanes" without env var set';

$ENV{PF_ENABLE_DB_DUMP} = 1;
lives_ok { $lanes= $f->_find_all_lanes(['pathogen_prok_track'], 'database') }
  'no exception from "_find_all_lanes" with env var set';

is scalar @$lanes, 236, 'got all lanes from "_find_all_lanes"';

$lanes = $f->_find_all_lanes(['pathogen_prok_track'], 'database', undef );
is scalar @$lanes, 236, '236 lanes from "_find_all_lanes" when "processed" is undef';
$lanes = $f->_find_all_lanes(['pathogen_prok_track'], 'database', 4096 );
is scalar @$lanes, 0, 'no lanes from "_find_all_lanes" when filtered on "processed"';
$lanes = $f->_find_all_lanes(['pathogen_prok_track'], 'database', undef, 'passed' );
is scalar @$lanes, 11, '11 lanes from "_find_all_lanes" when filtered on QC status';

#---------------------------------------

# check the behaviour of the lane_class attribute

# first, the default value
is $f->lane_class, 'Bio::Path::Find::Lane', 'lane class default is as expected';

throws_ok { $f = Bio::Path::Find::Finder->new( lane_class => 'my_class' ) }
  qr/does not pass the type constraint/,
  'exception when trying to use non-existent lane class';

# check that we can set the name of the role correctly using lane_class
lives_ok { $f = Bio::Path::Find::Finder->new( lane_class => 'Bio::Path::Find::Lane::Class::Data' ) }
  'no exception using valid lane class name';

# check "find_lanes"
lives_ok { $lanes = $f->find_lanes( ids => [ '10263_4' ], type => 'lane' ) }
  'no exception getting lanes when valid lane_class specified';

isa_ok $lanes->[0], 'Bio::Path::Find::Lane::Class::Data';
ok $lanes->[0]->does('Bio::Path::Find::Lane::Role::Stats'), 'Stats Role applied to Lane';

# make sure that we don't have any problems when we don't name a specific class
$f = Bio::Path::Find::Finder->new;

lives_ok { $lanes = $f->find_lanes( ids => [ '10263_4' ], type => 'lane' ) }
  'no exception getting lanes when script not named in default lane_roles';

isa_ok $lanes->[0], 'Bio::Path::Find::Lane';

#---------------------------------------

lives_ok { $lanes = $f->find_lanes( ids => [ 'pathogen_prok_track' ], type => 'database' ) }
  'no exception getting all lanes in database';

is scalar @$lanes, 236, 'got expected number of lanes with type "database"';

#-------------------------------------------------------------------------------

# done_testing;

