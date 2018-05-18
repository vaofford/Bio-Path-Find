# a dummy Role that provides the two required methods for the RNASeqSummary Role.

package TestRole;

use Moose::Role;

with 'Bio::Path::Find::Lane::Role::RNASeqSummary';

sub _build_summary_headers {
  [ 'one', 'two' ];
}

sub _build_summary {
  [ [ 1, 2, ] ];
}

#-------------------------------------------------------------------------------

package main;

use strict;
use warnings;

use Test::More tests => 6;
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

use_ok('Bio::Path::Find::Lane');

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
my $lane_rows = $database->schema->get_lanes_by_id(['10018_1#30'], 'lane');

my $lane_row = $lane_rows->first;
$lane_row->database($database);


#---------------------------------------

# get a Lane, with Role applied

my $lane;

lives_ok { $lane = Bio::Path::Find::Lane->with_traits('TestRole')
                                        ->new( row => $lane_row ) }
  'no exception when creating Lane with RNASeqSummary Role applied';

ok $lane->does('Bio::Path::Find::Lane::Role::RNASeqSummary'), 'lane has RNASeqSummary Role applied';


# make sure the overridden methods work
my $expected_headers = [ qw( one two ) ];
my $expected_summary   = [ [ 1, 2 ] ];

is_deeply $lane->summary_headers, $expected_headers, 'got expected headers';
is_deeply $lane->summary,         $expected_summary, 'got expected summary';

#---------------------------------------

# done_testing;
