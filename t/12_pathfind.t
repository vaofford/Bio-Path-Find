
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Output;
use Path::Class;
use File::Temp qw( tempdir );
use Archive::Tar;
use Cwd;
use Compress::Zlib;

# don't initialise l4p here because we want to test that command line logging
# is correctly set up by the AppRole

use_ok('Bio::Path::Find::App::PathFind');

# create a test log file and make sure it isn't already there
my $test_log = file('t/data/12_pathfind/_pathfind_test.log');
$test_log->remove;

#-------------------------------------------------------------------------------

# simple find - get samples for a lane
my %params = (
  environment => 'test',
  config_file => 't/data/12_pathfind/test.conf',
  id          => '10018_1',
  type        => 'lane',
);

my $pf;
lives_ok { $pf = Bio::Path::Find::App::PathFind->new(%params) } 'got a new pathfind app object';
isa_ok $pf, 'Bio::Path::Find::App::PathFind', 'pathfind app';
ok $pf->does('Bio::Path::Find::App::Role::AppRole'), 'PathFind class does AppRole';

my $expected_results = file 't/data/12_pathfind/expected_paths.txt';
my $expected = join '', $expected_results->slurp;
stdout_is { $pf->run } $expected, 'got expected paths on STDOUT';

ok -f $test_log, 'test log found';

my @log_lines = $test_log->slurp( chomp => 1 );
is scalar @log_lines, 1, 'got one log entry';

#-------------------------------------------------------------------------------

# check symlinking

# first, see if we can make symlinks in perl on this platform
my $symlink_exists = eval { symlink("",""); 1 }; # see perl doc for symlink
die "ERROR: can't create symlinks on this platform"
  unless $symlink_exists;

my $temp_dir = File::Temp->newdir;

$params{symlink} = dir $temp_dir;

lives_ok { $pf = Bio::Path::Find::App::PathFind->new(%params) }
  'got a pathfind app configured to make symlinks';

lives_ok { $pf->run }
  'no exception when making symlinks';

#-------------------------------------------------------------------------------

# check archiving

# set up a temp dir where we can write the archive
$temp_dir = File::Temp->newdir;
dir( $temp_dir, 't' )->mkpath;
my $orig_cwd = getcwd;
symlink( "$orig_cwd/t/data", "$temp_dir/t/data") == 1
  or die "ERROR: couldn't link data directory into temp directory";
chdir $temp_dir;

delete $params{symlink};
$params{archive} = 1;

lives_ok { $pf = Bio::Path::Find::App::PathFind->new(%params) }
  'no exception with "archive" option';

stdout_like { $pf->run }
  qr/Archiving lanes to 'pathfind_10018_1\.tar.gz'/,
  'archiving to correct file name';

my $tarfile = file('pathfind_10018_1.tar.gz');
ok -f $tarfile, 'found archive';

# check the archive
my $tar = Archive::Tar->new;
$tar->read($tarfile);

my @archived_files = $tar->list_files;

is scalar @archived_files, 50, 'got expected number of files in archive';
is $archived_files[0], '10018_1/10018_1#1_1.fastq.gz', 'first file looks right';
is $archived_files[-1], '10018_1/10018_1#51_1.fastq.gz', 'last file looks right';

my $gzipped_data = $tar->get_content('10018_1/10018_1#1_1.fastq.gz');
my $raw_data = Compress::Zlib::memGunzip($gzipped_data);
is $raw_data, "some data\n", 'first file has expected content';

unlink $tarfile;

# check renaming of files in the archive
$params{rename} = 1;

lives_ok { $pf = Bio::Path::Find::App::PathFind->new(%params) }
  'no exception with "rename" option';

stdout_like { $pf->run }
  qr/Archiving lanes to 'pathfind_10018_1\.tar.gz'/,
  'archiving to same file name';

ok -f $tarfile, 'found archive';

$tar = Archive::Tar->new;
$tar->read($tarfile);

@archived_files = $tar->list_files;

is scalar @archived_files, 50, 'got expected number of files in archive';
is scalar( grep(m/\#/, @archived_files) ), 0, 'filenames have been renamed';

unlink $tarfile;

# check we can supply a filename
$tarfile = 'test.tar.gz';
$params{archive} = $tarfile;

lives_ok { $pf = Bio::Path::Find::App::PathFind->new(%params) }
  'no exception with "archive" option giving archive name';

stdout_like { $pf->run }
  qr/Archiving lanes to 'test.tar.gz'/,
  'archiving to correctly named file';

ok -f $tarfile, 'found archive';

$tar = Archive::Tar->new;
$tar->read($tarfile);

@archived_files = $tar->list_files;

is scalar @archived_files, 50, 'got expected number of files in archive';

done_testing;

# tidy up after ourselves...
chdir $orig_cwd;
$test_log->remove;

