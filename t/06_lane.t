
use strict;
use warnings;

use Test::More;
use Test::Exception;

use Bio::Path::Find::DatabaseManager;

use_ok('Bio::Path::Find::Lane');

my $dbm = Bio::Path::Find::DatabaseManager->new(
  config_file => 't/data/06_lane/test.conf',
  environment => 'test',
);

my $database = $dbm->get_database('pathogen_test_pathfind');
my $lanes    = $database->schema->get_lanes_by_id('5477_6', 'lane');

my $lane_row = $lanes->first;
$lane_row->database($database);

my $lane;
lives_ok { $lane = Bio::Path::Find::Lane->new( row => $lane_row ) }
  'no exception with valid row';

ok   $lane->has_no_files, '"has_no_files" true';
ok ! $lane->has_files,    '"has_files" false';

# the DatabaseManager should catch this when building the Database objects, but
# we also check in the Lane object to make sure that the root directory is
# visible. If it's not, there might be a probem with filesystem mounts
my $old_rd = $database->hierarchy_root_dir;
$database->_set_hierarchy_root_dir('non-existent-dir');

throws_ok { $lane->root_dir }
  qr/can't see the filesystem root/,
  'exception with missing root directory';

$database->_set_hierarchy_root_dir($old_rd);

# find some files...
is $lane->find_files('fastq'), 2, 'found 2 fastq files for lane';
is $lane->find_files('bam'), 2, 'found 2 bam files for lane';


$DB::single = 1;

done_testing;

