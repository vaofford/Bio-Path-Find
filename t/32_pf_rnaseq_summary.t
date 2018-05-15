
use strict;
use warnings;

use Test::More tests => 4;
use Test::Exception;
use Test::Output;
use Test::Warn;
use Path::Class;
use File::Temp qw( tempdir );
use Cwd;
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

use_ok('Bio::Path::Find::App::PathFind::Data');

# set up a temp dir
my $temp_dir = File::Temp->newdir;
dir( $temp_dir, 't' )->mkpath;
my $orig_cwd = getcwd;
symlink dir( $orig_cwd, qw( t data ) ), dir( $temp_dir, qw( t data ) )
  or die "ERROR: couldn't link data directory into temp directory";
chdir $temp_dir;

#my $expected_stats_file         = file(qw( t data 14_pf_data_stats expected_stats.tsv ));
#my @expected_stats              = $expected_stats_file->slurp( chomp => 1, split => qr|\t| ); 

#-------------------------------------------------------------------------------

# get some test lanes using the Finder directly
my $f = Bio::Path::Find::Finder->new(
  config     => file( qw( t data 32_pf_rnaseq_summary test.conf ) ),
  lane_class => 'Bio::Path::Find::Lane::Class::Data',
);

my $lanes = $f->find_lanes( ids => [ '10018_1#30' ], type => 'lane' );
is scalar @$lanes, 1, 'found 1 lane with ID 10018_1#30 using Finder';
ok $lanes->[0]->does('Bio::Path::Find::Lane::Role::Stats'), 'Stats Role applied to Lanes';

#print Dumper $lanes;

#-------------------------------------------------------------------------------

# done_testing;

chdir $orig_cwd;
