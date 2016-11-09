
use strict;
use warnings;

use Test::More tests => 16;
use Test::Exception;
use Test::Output;
use Test::Warn;
use Path::Class;
use File::Temp qw( tempdir );
use Cwd;
use Compress::Zlib;
use Try::Tiny;
use Text::CSV_XS qw( csv );
use Capture::Tiny ':all';

# set up the "linked" directory for the test suite
use lib 't';

use Test::Setup;

unless ( -d dir( qw( t data linked ) ) ) {
  diag 'creating symlink directory';
  Test::Setup::make_symlinks;
}
use_ok('Bio::Path::Find::DatabaseManager');

use Bio::Path::Find::Finder;

# initialise l4p to avoid warnings
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init( $FATAL );

use_ok('Bio::Path::Find::App::PathFind::Data');

# set up a temp dir where we can write the archive
my $temp_dir = File::Temp->newdir;
dir( $temp_dir, 't' )->mkpath;
my $orig_cwd = getcwd;
symlink dir( $orig_cwd, qw( t data ) ), dir( $temp_dir, qw( t data ) )
  or die "ERROR: couldn't link data directory into temp directory";
chdir $temp_dir;

my $expected_stats_file         = file(qw( t data 14_pf_data_stats expected_stats.tsv ));
my @expected_stats              = $expected_stats_file->slurp( chomp => 1, split => qr|\t| );

#-------------------------------------------------------------------------------

# get some test lanes using the Finder directly
my $f = Bio::Path::Find::Finder->new(
  config     => file( qw( t data 14_pf_data_stats test.conf ) ),
  lane_class => 'Bio::Path::Find::Lane::Class::Data',
);

my $lanes = $f->find_lanes( ids => [ '10018_1' ], type => 'lane', filetype => 'fastq' );
is scalar @$lanes, 50, 'found 50 lanes with ID 10018_1 using Finder';
ok $lanes->[0]->does('Bio::Path::Find::Lane::Role::Stats'), 'Stats Role applied to Lanes';

#-------------------------------------------------------------------------------

# get a PathFind object

my %params = (
  # no need to pass "config_file"; it will come from the HasConfig Role
  id               => '10018_1',
  type             => 'lane',
  no_progress_bars => 1,
);

my $pf;
lives_ok { $pf = Bio::Path::Find::App::PathFind::Data->new(%params) }
  'got a new pathfind data command object';

# write to automatically generated filename
my $output;
lives_ok { $output = capture_merged { $pf->_make_stats($lanes) } }
  'no exception when calling _make_stats';

my $stats_file = file( $temp_dir, '10018_1.pathfind_stats.csv' );
ok -e $stats_file, 'stats named as expected';

my $stats = csv( in => $stats_file->stringify );

is_deeply $stats, \@expected_stats, 'written contents look right';

# write to specified filename

$stats_file = file( $temp_dir, 'named_file.csv' );

%params = (
  # no need to pass "config_file"; it will come from the HasConfig Role
  id               => '10018_1',
  type             => 'lane',
  stats            => $stats_file->stringify,
  no_progress_bars => 1,
);

$pf = Bio::Path::Find::App::PathFind::Data->new(%params);

lives_ok { $output = capture_merged { $pf->_make_stats($lanes) } }
  'no exception when calling _make_stats';

like $output, qr/Wrote statistics to .*?named_file\.csv/,
  'got message with filename';

ok -e $stats_file, 'stats named as expected';

$stats = csv( in => $stats_file->stringify );
# NOTE again, ignore the broken row
$stats->[5] = $expected_stats[5];
is_deeply $stats, \@expected_stats, 'contents of named file look right';

# should get an error when writing to the same file a second time
throws_ok { $output = capture_merged { $pf->_make_stats($lanes) } }
  qr/already exists/,
  'exception when calling _make_stats with existing file';

like $output, qr/Wrote statistics to .*?named_file\.csv/,
  'got message with filename';

$params{force} = 1;
$pf = Bio::Path::Find::App::PathFind::Data->new(%params);

lives_ok { $output = capture_merged { $pf->_make_stats($lanes) } }
  'no exception when calling _make_stats with existing file but "force" is set to true';

like $output, qr/Wrote statistics to .*?named_file\.csv/,
  'got message with filename';

#-------------------------------------------------------------------------------

# done_testing;

chdir $orig_cwd;

