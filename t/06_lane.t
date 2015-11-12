
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Output;

use Bio::Path::Find::DatabaseManager;

use_ok('Bio::Path::Find::Lane');

my $dbm = Bio::Path::Find::DatabaseManager->new(
  environment => 'test',
  config_file => 't/data/06_lane/test.conf',
);

my $database = $dbm->get_database('pathogen_prok_track');
my $lanes    = $database->schema->get_lanes_by_id('10018_1', 'lane');

is $lanes->count, 50, 'got 50 lanes';

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
my $old_hrd = $database->hierarchy_root_dir;
$database->_set_hierarchy_root_dir('non-existent-dir');

throws_ok { $lane->root_dir }
  qr/can't see the filesystem root/,
  'exception with missing root directory';

$database->_set_hierarchy_root_dir($old_hrd);

stdout_is { $lane->print_paths } 't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1
', 'printed expected path to directory for lane';

# find some files with specific types...
is $lane->find_files('fastq'), 1, 'found fastq file for lane';

# check print_files output
stdout_is { $lane->print_paths } 't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1/10018_1#1_1.fastq.gz
', 'printed expected path';

is $lane->find_files('bam'),   2, 'found 2 bam files for lane';
stdout_is { $lane->print_paths } 't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1/544477.se.markdup.bam
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1/544477.se.raw.sorted.bam
', 'printed expected paths';

lives_ok { $lane->status_files } 'no exception when finding status files';
my @pipelines = keys %{ $lane->status_files };
is scalar @pipelines, 1, 'got one status file';
is $pipelines[0], 'stored', 'got status file for "stored" pipeline';

done_testing;

