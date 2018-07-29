
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
use Data::Dumper;

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

use_ok('Bio::Path::Find::App::PathFind::RNASeq');

# set up a temp dir where we can write the archive
my $temp_dir = File::Temp->newdir;
dir( $temp_dir, 't' )->mkpath;
my $orig_cwd = getcwd;
symlink dir( $orig_cwd, qw( t data ) ), dir( $temp_dir, qw( t data ) )
  or die "ERROR: couldn't link data directory into temp directory";
chdir $temp_dir;

my $expected_summary_file         = file(qw( t data 32_pf_rnaseq_summary expected_summary.tsv ));
my @expected_summary              = $expected_summary_file->slurp( chomp => 1, split => qr|\t| );

#-------------------------------------------------------------------------------

# get some test lanes using the Finder directly
my $f = Bio::Path::Find::Finder->new(
  config     => file( qw( t data 32_pf_rnaseq_summary prod.conf ) ),
  lane_class => 'Bio::Path::Find::Lane::Class::RNASeq',
);

my $lanes = $f->find_lanes( ids => [ '10018_1#30' ], type => 'lane' );

is scalar @$lanes, 1, 'found 1 lane with ID 10018_1#30 using Finder';
ok $lanes->[0]->does('Bio::Path::Find::Lane::Role::RNASeqSummary'), 'RNASeqSummary Role applied to Lanes';

#-------------------------------------------------------------------------------

# get a PathFind object

my %params = (
  # no need to pass "config_file"; it will come from the HasConfig Role
  id               => '10018_1#30',
  type             => 'lane',
  no_progress_bars => 1,
);

my $pf;
lives_ok { $pf = Bio::Path::Find::App::PathFind::RNASeq->new(%params) }
  'got a new pathfind data command object';

# write to automatically generated filename
my $output;
lives_ok { $output = capture_merged { $pf->_make_summary($lanes) } }
  'no exception when calling _make_summary';

my $summary_file = file( $temp_dir, '10018_1_30.rnaseqfind_summary.tsv' );
ok -e $summary_file, 'summary named as expected';

my $summary = csv( in => $summary_file->stringify, sep=>"\t", quote_char  => undef );
is_deeply $summary, \@expected_summary, 'written contents look right';

# write to specified filename
$summary_file = file( $temp_dir, 'named_file.tsv' );

%params = (
  # no need to pass "config_file"; it will come from the HasConfig Role
  id               => '10018_1#30',
  type             => 'lane',
  summary          => $summary_file->stringify,
  no_progress_bars => 1,
);

$pf = Bio::Path::Find::App::PathFind::RNASeq->new(%params);

lives_ok { $output = capture_merged { $pf->_make_summary($lanes) } }
  'no exception when calling _make_summary';

like $output, qr/Wrote summary to .*?named_file\.tsv/,
  'got message with filename';

ok -e $summary_file, 'summary named as expected';

$summary = csv( in => $summary_file->stringify, sep=>"\t", quote_char  => undef  );
# NOTE again, ignore the broken row

$summary->[1] = $expected_summary[1];
is_deeply $summary, \@expected_summary, 'contents of named file look right';

# should get an error when writing to the same file a second time
throws_ok { $output = capture_merged { $pf->_make_summary($lanes) } }
  qr/already exists/,
  'exception when calling _make_summary with existing file';

like $output, qr/Wrote summary to .*?named_file\.tsv/,
  'got message with filename';

$params{force} = 1;
$pf = Bio::Path::Find::App::PathFind::RNASeq->new(%params);

lives_ok { $output = capture_merged { $pf->_make_summary($lanes) } }
  'no exception when calling _make_summary with existing file but "force" is set to true';

like $output, qr/Wrote summary to .*?named_file\.tsv/,
  'got message with filename';

#-------------------------------------------------------------------------------

# done_testing;

chdir $orig_cwd;

