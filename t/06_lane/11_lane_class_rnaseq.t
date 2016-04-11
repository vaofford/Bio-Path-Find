
use strict;
use warnings;

no warnings 'qw'; # avoid warnings about comments in list when we use lane/plex
                  # IDs in filenames

use Test::More tests => 10;
use Test::Exception;
use Path::Class;
use Cwd;

use Bio::Path::Find::Finder;

# set up logging
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init( $FATAL ); # initialise l4p to avoid warnings

# set up the "linked" directory for the test suite
use lib 't';

use Test::Setup;

unless ( -d dir( qw( t data linked ) ) ) {
  diag 'creating symlink directory';
  Test::Setup::make_symlinks;
}

# set up a temp dir where we can write files
my $temp_dir = File::Temp->newdir;
dir( $temp_dir, 't' )->mkpath;
my $orig_cwd = getcwd;
symlink dir( $orig_cwd, qw( t data ) ), dir( $temp_dir, qw( t data ) )
  or die "ERROR: couldn't link data directory into temp directory";

chdir $temp_dir;

# make sure we can compile the class that we're testing...
use_ok('Bio::Path::Find::Lane::Class::RNASeq');

#---------------------------------------

# use the Finder to get some lanes to play with
my $config = {
  db_root           => dir(qw( t data linked )),
  connection_params => {
    tracking => {
      driver       => 'SQLite',
      dbname       => file('t', 'data', 'pathogen_prok_track.db'),
      schema_class => 'Bio::Track::Schema',
    },
  },
  no_progress_bars => 1,
};

my $finder = Bio::Path::Find::Finder->new(
  config     => $config,
  lane_class => 'Bio::Path::Find::Lane::Class::RNASeq'
);

# NB lane "10018_1#30" and onwards are specifically set up for these tests

my $lanes;
lives_ok { $lanes = $finder->find_lanes( ids => [ '10018_1#30' ], type => 'lane' ) }
  'no exception when finding lanes';

is scalar @$lanes, 1, 'found one matching lane';

my $lane = $lanes->[0];

isa_ok $lane, 'Bio::Path::Find::Lane';
isa_ok $lane, 'Bio::Path::Find::Lane::Class::RNASeq';

#-------------------------------------------------------------------------------

# check "_edit_filenames"

my $from = file( qw( path ID file ) );
my $to   = file( qw( path ID ID.file ) );

my ( $src, $dst ) = $lane->_edit_filenames( $from, $from );

is "$src", "$from", '"_edit_filenames" returns source path unchanged';
is "$dst", "$to",   '"_edit_filenames" returns expected destination path';

#-------------------------------------------------------------------------------

# we can only test "_generate_filenames" indirectly, by calling
# Lane::find_files and letting that method call it.

my $expected_file = file( qw( t data linked prokaryotes seq-pipelines Actinobacillus pleuropneumoniae TRACKING 607 APP_N1_OP2 SLX APP_N1_OP2_7492554 10018_1#30 525345.se.markdup.bam.corrected.bam ) );

my @files = $lane->find_files('bam');
is $files[0], $expected_file, 'got expected file returned from "find_files"';

is $lane->file_count, 1, 'found one file';
is $lane->get_file(0), $expected_file, 'found file is correct';

#-------------------------------------------------------------------------------

# done_testing;

chdir $orig_cwd;

