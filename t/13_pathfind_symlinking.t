
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

use Bio::Path::Find::Finder;

# initialise l4p to avoid warnings
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init( $FATAL );

use_ok('Bio::Path::Find::App::PathFind');

# set up a temp dir where we can write the archive
my $temp_dir = File::Temp->newdir;
dir( $temp_dir, 't' )->mkpath;
my $orig_cwd = getcwd;
symlink( "$orig_cwd/t/data", "$temp_dir/t/data") == 1
  or die "ERROR: couldn't link data directory into temp directory";
chdir $temp_dir;

# create a test log file and make sure it isn't already there
my $test_log = file($temp_dir, '_pathfind_test.log');
$test_log->remove;

#-------------------------------------------------------------------------------

# get some test lanes using the Finder directly
my $f = Bio::Path::Find::Finder->new(
  environment => 'test',
  config_file => 't/data/13_pathfind_symlinking/test.conf',
  lane_role   => 'Bio::Path::Find::Lane::Role::PathFind',
);

my $lanes = $f->find_lanes( ids => [ '10018_1' ], type => 'lane', filetype => 'fastq' );
is scalar @$lanes, 50, 'found 50 lanes with ID 10018_1 using Finder';

#-------------------------------------------------------------------------------

# symlink attribute but no filename
my %params = (
  environment      => 'test',
  config_file      => 't/data/13_pathfind_symlinking/test.conf',
  id               => '10018_1',
  type             => 'lane',
  no_progress_bars => 1,
  symlink          => 1,
);

my $pf;
lives_ok { $pf = Bio::Path::Find::App::PathFind->new(%params) }
  'got a new pathfind app object';

my $dest = dir( $temp_dir, 'pathfind_10018_1' );

stderr_like { $pf->_make_symlinks($lanes) }
  qr|Creating links in '.*?/pathfind_10018_1'|, # STDOUT
  'creating links in correct directory; no progress bar';

# remove the links directory and do it again, this time checking for the
# absence of a progress bar

$dest->rmtree;

stderr_unlike { $pf->_make_symlinks($lanes) }
  qr|linking|,
  'no progress bar';

ok -d $dest, 'found link directory';

my @links = $dest->children;
is scalar( @links ), 50, 'found all links';

# link in a specific directory, this time with a progress bar

$params{no_progress_bars} = 0;
$params{symlink}          = 'my_link_dir';
$pf = Bio::Path::Find::App::PathFind->new(%params);

$dest = dir( $temp_dir, 'my_link_dir' );

stderr_like { $pf->_make_symlinks($lanes) }
  qr/Creating links in 'my_link_dir'.*?linking/s,
  'creating links in correct directory; progress bar shown';

ok -d $dest, 'found link directory';

@links = $dest->children;
is scalar( @links ), 50, 'found all links';

# see what happens when we can't mkdir the specified dir

$params{symlink} = '/var/my_link_dir'; # not very cross-platform...
$pf = Bio::Path::Find::App::PathFind->new(%params);

$dest = dir( '/var/my_link_dir' );

throws_ok { $pf->_make_symlinks($lanes) }
  qr/couldn't make link directory/,
  'exception when trying to mkdir in /var';

# look for exception when directory already exists as a file
file( $temp_dir, 'pre-existing-file' )->touch;

$params{symlink} = 'pre-existing-file';
$pf = Bio::Path::Find::App::PathFind->new(%params);

throws_ok { $pf->_make_symlinks($lanes) }
  qr/couldn't make link directory/,
  'exception when destination exists as a file';

#-------------------------------------------------------------------------------

done_testing;

# tidy up after ourselves...
chdir $orig_cwd;
$test_log->remove;

