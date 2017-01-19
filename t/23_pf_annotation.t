
#-------------------------------------------------------------------------------
#- wrapping class --------------------------------------------------------------
#-------------------------------------------------------------------------------

# the idea of this class is to wrap up the original PathFind::Annotation
# command class and replace the various _make_* methods, which are tested in
# separate test scripts, with dummy "around" modifiers. That will allow us to
# test the run method without actually calling the concrete methods.

package Bio::Path::Find::App::TestFind;

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

extends 'Bio::Path::Find::App::PathFind::Annotation';

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

# we want to test "_find_genes", so we won't override that method

#-------------------------------------------------------------------------------
#- main test script ------------------------------------------------------------
#-------------------------------------------------------------------------------

package main;

use strict;
use warnings;

use Test::More tests => 17;
use Test::Exception;
use Test::Warn;
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
my %params = (
  config => $config,
  id     => '10018_1',
  type   => 'lane',
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
$params{symlink} = 'my_links_dir';
$tf->clear_config;
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

# test "_find_genes"

# we don't really care about these params; we're going to get a reference to
# the Finder object and tell it the parameters directly
my %tf_params = (
  config => $config,
  id     => '10018_1#3',
  type   => 'lane',
);

$tf->clear_config;
$tf = Bio::Path::Find::App::TestFind->new(%tf_params);

my %finder_params = (
  ids      => ['10018_1'],
  type     => 'lane',
  filetype => 'gff',
  subdirs  => [
    dir(qw( iva_assembly annotation )),
    dir(qw( spades_assembly annotation )),
    dir(qw( velvet_assembly annotation )),
    dir(qw( pacbio_assembly annotation )),
  ],
  lane_attributes => {
    search_depth    => 3,
    store_filenames => 1,
  },
);

my $lanes = $tf->_finder->find_lanes(%finder_params);

throws_ok { $tf->_find_genes($lanes) }
  qr/\(search_qualifiers\) is required/,
  'exception from _find_genes when neither gene or product is given';

# search by gene name
$tf_params{gene} = 'gag';
$tf->clear_config;
$tf = Bio::Path::Find::App::TestFind->new(%tf_params);

$lanes = $tf->_finder->find_lanes(%finder_params);

stdout_like { $tf->_find_genes($lanes) }
  qr/containing.*?\t3.*?missing.*?\t1/s,
  'got expected counts from "_find_genes" when looking for a gene';

# check for an output file
ok -f 'output.gag.fa', 'found expected output file';

# search by product name

delete $tf_params{gene};
$tf_params{product} = 'HIV_PBS';

$tf->clear_config;
$tf = Bio::Path::Find::App::TestFind->new(%tf_params);

$lanes = $tf->_finder->find_lanes(%finder_params);

stdout_like { $tf->_find_genes($lanes) }
  qr/containing.*?\t1.*?missing.*?\t3/s,
  'got expected counts from "_find_genes" when looking for a product';

ok -f 'output.HIV_PBS.fa', 'found expected output file';

ok grep( m/LW\*LEIPQTPFVSVENL\*QWRPNRDLKAKVRPE/, file('output.HIV_PBS.fa')->slurp ),
  'got amino-acid sequences in output file';

# check the nucleotide output and check we can change the output filename

$tf_params{nucleotides} = 1;
$tf_params{output}      = 'nucleotide_seq.fa';
$tf->clear_config;
$tf = Bio::Path::Find::App::TestFind->new(%tf_params);

stdout_like { $tf->_find_genes($lanes) }
  qr/Outputting nucleotide sequences/,
  'got message about outputting nucleotides';

ok grep( m/CTCTGGTAACTAGAGATCCCTCAGACACCTTTTGTCAGTGTGGAAAATCTCTAGCAGTGG/, file('nucleotide_seq.fa')->slurp ),
  'got nucleotide sequences in output file';

# try searching with both gene and product name

$tf_params{gene} = 'gag';
$tf_params{product} = 'HIV_PBS';

$tf->clear_config;
$tf = Bio::Path::Find::App::TestFind->new(%tf_params);

$lanes = $tf->_finder->find_lanes(%finder_params);

# need to test this using stderr_like, not warning_like, because it's not
# a warning or a carp, but some text printed to STDERR
combined_like { $tf->_find_genes($lanes) }
  qr/searching for genes and products/,
  'got warning when specifying both gene and product name';

# (can't check case where command line has "-g X -p"; check that in the test
# script that covers the shell command)

#-------------------------------------------------------------------------------

# done_testing;

chdir $orig_cwd;

__DATA__
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1/iva_assembly/annotation/10018_1#1.gff
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1/spades_assembly/annotation/10018_1#1.gff
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_2/SLX/APP_IN_2_7492527/10018_1#2/spades_assembly/annotation/10018_1#2.gff
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T1_OP2/SLX/APP_T1_OP2_7492533/10018_1#3/spades_assembly/annotation/10018_1#3.gff
