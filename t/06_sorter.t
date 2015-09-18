
use strict;
use warnings;

use Test::More;
use Test::Exception;

use Bio::Path::Find::Database;

use_ok(' Bio::Path::Find::Sorter');

my $sorter;
lives_ok { $sorter = Bio::Path::Find::Sorter->new(environment => 'test', config_file => 't/data/06_sorter/test.conf') }
  'got a sorter';

my $db_finder = Bio::Path::Find::Database->new(environment => 'test', config_file => 't/data/06_sorter/test.conf');

my $schema = $db_finder->get_schema('pathogen_test_track');

my $unsorted_rs = $schema->get_lanes_by_id('5477_6','lane');
my @unsorted_lanes = $unsorted_rs->all;

my @expected_order = (
  '5477_6#11',
  '5477_6#12',
  '5477_6#3',
  '5477_6#4',
);

my @actual_order;
push @actual_order, $_->name for @unsorted_lanes;

is_deeply \@actual_order, \@expected_order, 'UNSORTED lane names in expected order';

my $sorted_lanes = $sorter->sort_lanes(\@unsorted_lanes);

@expected_order = (
  '5477_6#3',
  '5477_6#4',
  '5477_6#11',
  '5477_6#12',
);

@actual_order = ();
push @actual_order, $_->name for @$sorted_lanes;

is_deeply \@actual_order, \@expected_order, 'SORTED lane names in expected order';

# TODO this needs way more test cases

$DB::single = 1;

done_testing;

