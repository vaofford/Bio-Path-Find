
use strict;
use warnings;

use Test::More;
use Test::Exception;

use Bio::Path::Find::DatabaseManager;
use Bio::Path::Find::Lane;

use_ok('Bio::Path::Find::Sorter');

my $sorter;
lives_ok { $sorter = Bio::Path::Find::Sorter->new(environment => 'test', config_file => 't/data/08_sorter/test.conf') }
  'got a sorter';

my $dbm = Bio::Path::Find::DatabaseManager->new(environment => 'test', config_file => 't/data/08_sorter/test.conf');

my $schema = $dbm->get_database('pathogen_prok_track')->schema;
# my $schema = $dbm->get_database('pathogen_track_test')->schema;

my $unsorted_rs = $schema->get_lanes_by_id('5477_6','lane');
my @unsorted_lane_rows = $unsorted_rs->all;

# the order of the UNsorted lanes directly from the database
my @expected_order = (
  '5477_6#1',
  '5477_6#10',
  '5477_6#11',
  '5477_6#2',
  '5477_6#3',
  '5477_6#4',
  '5477_6#5',
  '5477_6#6',
  '5477_6#7',
  '5477_6#8',
  '5477_6#9',
);

my @actual_order;
push @actual_order, $_->name for @unsorted_lane_rows;

is_deeply \@actual_order, \@expected_order, 'UNSORTED lane names in expected order';

my @unsorted_lanes;
push @unsorted_lanes, new Bio::Path::Find::Lane(row => $_) for @unsorted_lane_rows;

my $sorted_lanes = $sorter->sort_lanes(\@unsorted_lanes);

@expected_order = (
  '5477_6#1',
  '5477_6#2',
  '5477_6#3',
  '5477_6#4',
  '5477_6#5',
  '5477_6#6',
  '5477_6#7',
  '5477_6#8',
  '5477_6#9',
  '5477_6#10',
  '5477_6#11',
);

@actual_order = ();
push @actual_order, $_->row->name for @$sorted_lanes;

is_deeply \@actual_order, \@expected_order, 'SORTED lane names in expected order';

# TODO this needs way more test cases

$DB::single = 1;

done_testing;

