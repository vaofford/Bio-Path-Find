
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Output;
use Test::Warn;
use Path::Class;
use File::Temp qw( tempdir );
use Cwd;
use Compress::Zlib;
use Try::Tiny;
use Text::CSV_XS qw( csv );

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

my $expected_stats_file         = file(qw( t data 14_pathfind_stats expected_stats.tsv ));
my $expected_stats_file_content = $expected_stats_file->slurp;
my @expected_stats              = $expected_stats_file->slurp( chomp => 1, split => qr|\t| );

#-------------------------------------------------------------------------------

# get some test lanes using the Finder directly
my $f = Bio::Path::Find::Finder->new(
  environment => 'test',
  config_file => 't/data/14_pathfind_stats/test.conf',
  lane_role   => 'Bio::Path::Find::Lane::Role::PathFind',
);

my $lanes = $f->find_lanes( ids => [ '10018_1' ], type => 'lane', filetype => 'fastq' );
is scalar @$lanes, 50, 'found 50 lanes with ID 10018_1 using Finder';

#-------------------------------------------------------------------------------

# get a PathFind object

my %params = (
  environment      => 'test',
  config_file      => 't/data/14_pathfind_stats/test.conf',
  id               => '10018_1',
  type             => 'lane',
  no_progress_bars => 1,
);

my $pf;
lives_ok { $pf = Bio::Path::Find::App::PathFind->new(%params) }
  'got a new pathfind app object';

# write to automatically generated filename

lives_ok { $pf->_make_stats($lanes) } 'no exception when calling _make_stats';

my $stats_file = file( $temp_dir, '10018_1.pathfind_stats.csv' );
ok -e $stats_file, 'stats named as expected';

my $stats = csv( in => $stats_file->stringify );
is_deeply $stats, \@expected_stats, 'written contents look right';

# write to specified filename

$stats_file = file( $temp_dir, 'named_file.csv' );

%params = (
  environment      => 'test',
  config_file      => 't/data/14_pathfind_stats/test.conf',
  id               => '10018_1',
  type             => 'lane',
  stats            => $stats_file->stringify,
  no_progress_bars => 1,
);

$pf = Bio::Path::Find::App::PathFind->new(%params);

lives_ok { $pf->_make_stats($lanes) } 'no exception when calling _make_stats';

ok -e $stats_file, 'stats named as expected';

$stats = csv( in => $stats_file->stringify );
is_deeply $stats, \@expected_stats, 'contents of named file look right';

#-------------------------------------------------------------------------------

done_testing;

chdir $orig_cwd;

