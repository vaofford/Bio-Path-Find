
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Output;
use Test::Warn;
use Path::Class;

use Bio::Path::Find::DatabaseManager;

use Log::Log4perl qw( :easy );

# initialise l4p to avoid warnings
Log::Log4perl->easy_init( $FATAL );

use_ok('Bio::Path::Find::Lane');

my $dbm = Bio::Path::Find::DatabaseManager->new(
  environment => 'test',
  config_file => 't/data/06_lane/test.conf',
);

my $database  = $dbm->get_database('pathogen_prok_track');
my $lane_rows = $database->schema->get_lanes_by_id('10018_1', 'lane');

is $lane_rows->count, 50, 'got 50 lanes';

my $lane_row = $lane_rows->first;
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

# status object
isa_ok $lane->status, 'Bio::Path::Find::LaneStatus', 'lane status object';
is $lane->pipeline_status('stored'), 'Done', 'got pipeline status directly from the Lane';

# symlinking

# first, see if we can make symlinks in perl on this platform
my $symlink_exists = eval { symlink("",""); 1 }; # see perl doc for symlink

SKIP: {
  skip "can't create symlinks on this platform", 9 unless $symlink_exists;

  my $symlink_dir = dir 't/data/06_lane/_temp';
  $symlink_dir->rmtree;
  $symlink_dir->mkpath;

  # should work
  lives_ok { $lane->make_symlinks($symlink_dir) }
    'no exception when creating symlinks';

  my @files_in_temp_dir = $symlink_dir->children;
  is scalar @files_in_temp_dir, 2, 'found 2 links';

  ok -l 't/data/06_lane/_temp/544477.se.raw.sorted.bam', 'found one expected link';
  ok -l 't/data/06_lane/_temp/544477.se.markdup.bam', 'found other expected link';

  # should warn that file already exists
  warnings_like { $lane->make_symlinks($symlink_dir) }
    { carped => [ qr/is already a symlink/, qr/is already a symlink/ ] },
    'warnings when symlinks already exist';

  # replace one of the symlinks by a real file
  $files_in_temp_dir[0]->remove;
  $files_in_temp_dir[1]->remove;

  $files_in_temp_dir[0]->touch;
  warning_like { $lane->make_symlinks($symlink_dir) }
    { carped => [ qr/already exists/ ] },
    'warning when destination file already exists';

  $files_in_temp_dir[0]->remove;
  $files_in_temp_dir[1]->remove;

  # set the permissions on the directory to remove write permission
  chmod 0500, $symlink_dir;

  warnings_like { $lane->make_symlinks($symlink_dir) }
    { carped => [ qr/failed to create symlink/, qr/failed to create symlink/ ] },
    'warnings when destination directory not writeable';

  # should fail to find files to link
  $symlink_dir->rmtree;
  $symlink_dir->mkpath;

  warning_like { $lane->make_symlinks($symlink_dir, 'corrected') }
    { carped => qr/no files found for linking/ },
    'warning when no files found with specified type';

  is $lane->make_symlinks($symlink_dir, 'fastq'), 1, 'created expected one link for fastq';

  $symlink_dir->rmtree;
}

# check the stats for a lane

# get a new lane and apply the trait that produces stats appropriate for the
# pathfind script
lives_ok { $lane = Bio::Path::Find::Lane->with_traits('Bio::Path::Find::Lane::Role::PathFind')
                                        ->new( row => $lane_row ) }
  'no exception when applying Stats::Path trait to lane';

my $expected_stats = [
  '607',
  'APP_N2_OP1',
  '10018_1#1',
  '47',
  '397141',
  '18665627',
  'QC',
  'Streptococcus_suis_P1_7_v1',
  '2007491',
  'bwa',
  '525354',
  '0.0',
  '0.0',
  '0',
  '0.00',
  '0.01',
  '2.3',
  '90.2',
  '0.00',
  '0.0000',
  '0.044',
  'pending',
  'pending',
  '1',
  '2.0868283360403e-05',
  '0.0112145340361108',
  '3.57142857142857',
  'Done',
  'Done',
  'Done',
  '-',
  '-',
  '-',
  '-',
];

is_deeply $lane->stats, $expected_stats, 'got expected stats for lane';

done_testing;

