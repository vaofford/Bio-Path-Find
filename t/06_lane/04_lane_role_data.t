
use strict;
use warnings;

use Test::More tests => 14;
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
my $lane_rows = $database->schema->get_lanes_by_id('10018_1', 'lane');

my $lane_row = $lane_rows->first;
$lane_row->database($database);

#---------------------------------------

# get a Lane, with Role applied

my $lane;

# apply a trait when creating the Lane, so that the "_get_fastq" method
# is available
lives_ok { $lane = Bio::Path::Find::Lane->with_traits('Bio::Path::Find::Lane::Role::Data')
                                        ->new( row => $lane_row ) }
  'no exception when creating Lane with applied Role';

SKIP: {
  skip "can't check path printing except on unix", 3,
    unless file( qw( t data linked ) ) eq 't/data/linked';

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
};

# status object
isa_ok $lane->status, 'Bio::Path::Find::Lane::Status', 'lane status object';
is $lane->pipeline_status('stored'), 'Done', 'got pipeline status directly from the Lane';

#---------------------------------------

# symlinking

# first, see if we can make symlinks in perl on this platform
my $symlink_exists = eval { symlink("",""); 1 }; # see perl doc for symlink

SKIP: {
  skip "can't create symlinks on this platform", 10 unless $symlink_exists;

  # set up a temp directory as the destination
  my $temp_dir = File::Temp->newdir;
  my $symlink_dir = dir $temp_dir;

  # should work
  lives_ok { $lane->make_symlinks( dest => $symlink_dir ) }
    'no exception when creating symlinks';

  is $lane->make_symlinks( dest => $symlink_dir, filetype => 'fastq' ), 1,
    'created expected one link for fastq';

  # check renaming (conversion of hashes to underscores in filename)  when
  # linking to a file
  $lane->make_symlinks(
    dest     => $symlink_dir,
    rename   => 1,
    filetype => 'fastq',
  );

  ok -l file( $symlink_dir, '10018_1_1_1.fastq.gz' ), 'found renamed link';
}

# check the stats for a lane

my $expected_stats = [
  [
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
  ]
];

is_deeply $lane->stats, $expected_stats, 'got expected stats for lane';

# done_testing;

