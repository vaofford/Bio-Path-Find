
#-------------------------------------------------------------------------------
#- wrapping class --------------------------------------------------------------
#-------------------------------------------------------------------------------

# the idea of this class is to wrap up the original PathFind::Assembly command
# class and replace the various _make_* methods, which are tested in separate
# test scripts, with dummy "around" modifiers. That will allow us to test the
# run method without actually calling the concrete methods.

package Bio::Path::Find::App::TestFind;

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

extends 'Bio::Path::Find::App::PathFind::Assembly';

around '_make_symlinks' => sub {
  print STDERR 'called _make_symlinks';
};

around '_make_tar' => sub {
  print STDERR 'called _make_tar';
};

around '_make_zip' => sub {
  print STDERR 'called _make_zip';
};

around '_make_stats' => sub {
  print STDERR 'called _make_stats';
};

#-------------------------------------------------------------------------------
#- main test script ------------------------------------------------------------
#-------------------------------------------------------------------------------

package main;

use strict;
use warnings;

use Test::More tests => 8;
use Test::Exception;
use Test::Output;
use Path::Class;
use File::Temp;
use Cwd;

# set up the "linked" directory for the test suite
use lib 't';

use Test::Setup;

unless ( -d dir( qw( t data linked ) ) ) {
  diag 'creating symlink directory';
  Test::Setup::make_symlinks;
}

use Bio::Path::Find::Finder;

# don't initialise l4p here because we want to test that command line logging
# is correctly set up by the AppRole

use_ok('Bio::Path::Find::App::TestFind');

# set up a temp dir where we can write files
my $temp_dir = File::Temp->newdir;
dir( $temp_dir, 't' )->mkpath;
my $orig_cwd = getcwd;
symlink dir( $orig_cwd, qw( t data ) ), dir( $temp_dir, qw( t data ) )
  or die "ERROR: couldn't link data directory into temp directory";
chdir $temp_dir;

# the basic params. These will stay unchanged for all of the subsequent runs
my %params = (
  config => {
    db_root           => dir(qw( t data linked )),
    connection_params => {
      tracking => {
        driver       => 'SQLite',
        dbname       => file(qw( t data pathogen_prok_track.db )),
        schema_class => 'Bio::Track::Schema',
      },
    },
  },
  id   => '10018_1',
  type => 'lane',
);

my $tf;
lives_ok { $tf = Bio::Path::Find::App::TestFind->new(%params) }
  'got a new testfind app object';

# print paths
my $file_list = join '', <DATA>;
stdout_is { $tf->run }
  $file_list,
  'printed correct paths';

# make symlinks

# clear config or we'll get errors about re-initializing singletons
$tf->clear_config;

$params{symlink} = 'my_links_dir';
$tf = Bio::Path::Find::App::TestFind->new(%params);
stderr_is { $tf->run } 'called _make_symlinks', 'correctly called _make_symlinks';

# make tar
delete $params{symlink};
$params{archive} = 'my_archive';
$tf->clear_config;
$tf = Bio::Path::Find::App::TestFind->new(%params);
stderr_is { $tf->run } 'called _make_tar', 'correctly called _make_tar';

# make tar
delete $params{archive};
$params{zip} = 'my_zip';
$tf->clear_config;
$tf = Bio::Path::Find::App::TestFind->new(%params);
stderr_is { $tf->run } 'called _make_zip', 'correctly called _make_zip';

# make stats
delete $params{zip};
$params{stats} = 'my_stats';
$tf->clear_config;
$tf = Bio::Path::Find::App::TestFind->new(%params);
stderr_is { $tf->run } 'called _make_stats', 'correctly called _make_stats';

# multiple flags
$params{archive} = 'my_tar';
$params{stats}   = 'my_stats';
$params{zip}     = 'my_zip';
$tf->clear_config;
$tf = Bio::Path::Find::App::TestFind->new(%params);
stderr_like { $tf->run }
  qr/called _make_tar.*?_make_zip.*?_make_stats/,
  'correctly called multiple _make_* methods';

#-------------------------------------------------------------------------------

# done_testing;

chdir $orig_cwd;

__DATA__
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T5_OP1/SLX/APP_T5_OP1_7492574/10018_1#50/iva_assembly/contigs.fa
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T5_OP1/SLX/APP_T5_OP1_7492574/10018_1#50/spades_assembly/contigs.fa
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T5_OP2/SLX/APP_T5_OP2_7492575/10018_1#51/velvet_assembly/contigs.fa
