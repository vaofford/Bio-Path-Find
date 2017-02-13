
use strict;
use warnings;

use Test::More tests => 23;
use Test::Exception;
use Test::Output;
use Test::Warn;
use Path::Class;
use File::Temp qw( tempdir );
use Cwd;
use Log::Log4perl qw( :easy );

use Bio::Path::Find::DatabaseManager;

# set up the "linked" directory for the test suite
use lib 't';

use Test::Setup;

unless ( -d dir( qw( t data linked ) ) ) {
  diag 'creating symlink directory';
  Test::Setup::make_symlinks;
}

# initialise l4p to avoid warnings
Log::Log4perl->easy_init( $FATAL );

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

my $database     = $dbm->get_database('pathogen_prok_track');
my $lane_rows_rs = $database->schema->get_lanes_by_id(['10018_1'], 'lane');

is $lane_rows_rs->count, 50, 'got 50 lanes';

my $lane_row = $lane_rows_rs->first;
$lane_row->database($database);

#---------------------------------------

# check creation

use_ok('Bio::Path::Find::Lane');

my $lane;
lives_ok { $lane = Bio::Path::Find::Lane->new( row => $lane_row ) }
  'no exception with valid row and no Role';

ok   $lane->has_no_files, '"has_no_files" true';
ok ! $lane->has_files,    '"has_files" false';

{
  no warnings 'qw';
  is $lane->storage_path, file( qw( t data master hashed_lanes pathogen_prok_track a 0 9 9 10018_1#1 ) ),
    'storage path is correct';
}

# the DatabaseManager should catch this when building the Database objects, but
# we also check in the Lane object to make sure that the root directory is
# visible. If it's not, there might be a probem with filesystem mounts
my $old_hrd = $database->hierarchy_root_dir;
$database->_set_hierarchy_root_dir(dir 'non-existent-dir');

throws_ok { $lane->root_dir }
  qr/can't see the filesystem root/,
  'exception with missing root directory';

$database->_set_hierarchy_root_dir($old_hrd);


#---------------------------------------

# file finding

# this Lane object doesn't have the "_get_fastq" method, which comes from the
# sub-class, Bio::Path::Find::Lane::Class::Data, so it's only means of finding
# files is the extension mapping mechanism
is $lane->find_files('fastq'), 0, 'no files found without mapping';

my $lane_with_extension_mapping = Bio::Path::Find::Lane->new(
  row                 => $lane_row,
  filetype_extensions => {
    fastq => '*.fastq.gz',
  },
);

is $lane_with_extension_mapping->find_files('fastq'), 2, 'found 2 file using mapping';
# (finds both the ".fastq.gz" file, and the ".corrected.fastq.gz" file)

# check that running "find_files" in array context returns a list of files
my @found_files = $lane_with_extension_mapping->find_files('fastq');
is scalar @found_files, 2, '"find_files" returns found files in list context';

# check "store_filenames" behaviour

isa_ok $found_files[0], 'Path::Class::File';

my $lane_storing_filenames = Bio::Path::Find::Lane->new(
  row                 => $lane_row,
  store_filenames     => 1,
  filetype_extensions => {
    fastq => '*.fastq.gz',
  },
);

@found_files = $lane_storing_filenames->find_files('fastq');

ok ! ref $found_files[0], 'files stored as filenames when attribute set';

#---------------------------------------

# symlinking

# first, see if we can make symlinks in perl on this platform
my $symlink_exists = eval { symlink("",""); 1 }; # see perl doc for symlink

SKIP: {
  skip "can't create symlinks on this platform", 8 unless $symlink_exists;

  # set up a temp directory as the destination
  my $temp_dir = File::Temp->newdir;
  my $symlink_dir = dir $temp_dir;

  # should work but not create links (no files found)
  warning_like { $lane->make_symlinks( dest => $symlink_dir ) }
    { carped => qr/no files found for linking/ },
    'warning about no files when creating symlinks';

  my @files_in_temp_dir = $symlink_dir->children;
  is scalar @files_in_temp_dir, 0, 'no links created';

  # switch to a lane which has a file extension mapping set and can therefore
  # actually find files
  $lane = $lane_with_extension_mapping;

  lives_ok { $lane->find_files('fastq') } 'no problem finding fastq files';

  lives_ok { $lane->make_symlinks( dest => $symlink_dir ) }
    'no problem creating links';

  @files_in_temp_dir = $symlink_dir->children;
  is scalar @files_in_temp_dir, 2, 'found 2 links';

  like $files_in_temp_dir[0], qr/10018_1#1/, 'link looks correct';

  # should warn that link already exists
  warnings_like { $lane->make_symlinks( dest => $symlink_dir ) }
    [ { carped => qr/is already a symlink/ },
      { carped => qr/is already a symlink/ } ],
    'warnings when symlinks already exist';

  # replace the symlinks by real files
  $files_in_temp_dir[0]->remove;
  $files_in_temp_dir[1]->remove;
  $files_in_temp_dir[0]->touch;
  $files_in_temp_dir[1]->touch;

  warnings_like { $lane->make_symlinks( dest => $symlink_dir ) }
    [ { carped => qr/already exists/ },
      { carped => qr/already exists/ } ],
    'warnings when destination files already exist';

  $files_in_temp_dir[0]->remove;
  $files_in_temp_dir[1]->remove;
  $lane->_clear_finding_run;
  $lane->clear_files;

  # re-make the temp dir
  $temp_dir = File::Temp->newdir;
  $symlink_dir = dir $temp_dir;

  # create links in the cwd
  $temp_dir = File::Temp->newdir;
  $symlink_dir = dir $temp_dir;
  my $orig_cwd = cwd;
  chdir $symlink_dir;

  lives_ok { $lane->make_symlinks }
    'no exception when creating symlinks in working directory';

  # should be a link to the directory for the lane in the current working directory
  my $link = dir( $symlink_dir, '10018_1#1' );
  ok -l $link, 'found directory link';

  $link->rmtree;

  # (it would be nice to be able to verify that the link actually points to the
  # intended directory, but because the link is to a relative path, it's never
  # going to resolve properly.)
  $lane->make_symlinks( rename => 1 );

  ok -l dir( $symlink_dir, '10018_1_1' ), 'found renamed dir';

  chdir $orig_cwd;

}

# done_testing;

