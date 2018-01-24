
#-------------------------------------------------------------------------------
#- wrapping class --------------------------------------------------------------
#-------------------------------------------------------------------------------

# the idea of this class is to wrap up the original command class and replace
# the various _make_* methods, which are tested in separate test scripts, with
# dummy "around" modifiers. That will allow us to test the run method without
# actually calling the concrete methods.

package Bio::Path::Find::App::TestFind;

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

extends 'Bio::Path::Find::App::PathFind::RNASeq';

around '_make_symlinks' => sub {
  print STDERR 'called _make_symlinks';
};
around '_make_tar'      => sub {
  print STDERR 'called _make_tar';
};
around '_make_zip'      => sub {
  print STDERR 'called _make_zip';
};
around '_make_stats'    => sub {
  print STDERR 'called _make_stats';
};

#-------------------------------------------------------------------------------
#- main test script ------------------------------------------------------------
#-------------------------------------------------------------------------------

package main;

use strict;
use warnings;

no warnings 'qw'; # don't warn about comments in lists when we put plux IDs
                  # inside qw( )

use Test::More tests => 27;
use Test::Exception;
use Test::Output;
use Test::Warn;
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

# don't initialise l4p here because we want to test that command line logging
# is correctly set up by the App class

use_ok('Bio::Path::Find::App::PathFind::RNASeq');

# set up a temp dir where we can write files
my $temp_dir = File::Temp->newdir;
dir( $temp_dir, 't' )->mkpath;
my $orig_cwd = getcwd;
symlink dir( $orig_cwd, qw( t data ) ), dir( $temp_dir, qw( t data ) )
  or die "ERROR: couldn't link data directory into temp directory";
chdir $temp_dir;

#-------------------------------------------------------------------------------

my %params = (
  config => {
    db_root           => dir(qw( t data linked )),
    connection_params => {
      tracking => {
        driver       => 'SQLite',
        dbname       => file(qw( t data pathogen_prok_track.db ))->stringify,
        schema_class => 'Bio::Track::Schema',
      },
    },
    refs_index => file(qw( t data 31_pf_rnaseq refs.index ))->stringify,
    refs_root  => file(qw( t data 31_pf_rnaseq            ))->stringify,
  },
  no_progress_bars   => 1,
  id                 => '10018_1#30',
  type               => 'lane',
  no_tar_compression => 1,
);

# make sure a sensible config and sensible query get us the output we expect
my $sf;
lives_ok { $sf = Bio::Path::Find::App::PathFind::RNASeq->new(%params) }
  'got a new RNASeq command object';

#-------------------------------------------------------------------------------

# check the builders that set the name of the output files

is $sf->_tar, '10018_1_30.rnaseqfind.tar', 'uncompressed tar file has correct name';

delete $params{no_tar_compression};
$sf->clear_config;
$sf = Bio::Path::Find::App::PathFind::RNASeq->new(%params);

is $sf->_tar,        '10018_1_30.rnaseqfind.tar.gz',    'gzipped tar file has correct name';
is $sf->_zip,        '10018_1_30.rnaseqfind.zip',       'zip file has correct name';
is $sf->_stats_file, '10018_1_30.rnaseqfind_stats.csv', 'stats file has correct name';

#-------------------------------------------------------------------------------

my $expected_path = dir( qw( t data linked prokaryotes seq-pipelines Actinobacillus pleuropneumoniae TRACKING 607 APP_N1_OP2 SLX APP_N1_OP2_7492554 10018_1#30 ) );
my %expected_files = ();
$expected_files{bam}           = file( $expected_path, '544507.se.raw.sorted.bam.corrected.bam' );
$expected_files{coverage}      = file( $expected_path, '544507.se.raw.sorted.bam.all_for_tabix.coverageplot.gz' );
$expected_files{featurecounts} = file( $expected_path, '544507.se.raw.sorted.bam.featurecounts.csv' );
$expected_files{intergenic}    = file( $expected_path, '544507.se.raw.sorted.bam.CP001234.tab.gz' );
$expected_files{spreadsheet}   = file( $expected_path, '544507.se.raw.sorted.bam.expression.csv' );

stdout_is { $sf->run } "$expected_files{spreadsheet}\n", 'got expected spreadsheet CSV with no filetype';

# 5 tests in here
foreach my $filetype ( qw( bam coverage featurecounts spreadsheet ) ) {
  $params{filetype} = $filetype;
  $sf->clear_config;
  $sf = Bio::Path::Find::App::PathFind::RNASeq->new(%params);
  stdout_is { $sf->run } "$expected_files{$filetype}\n",
    qq(got correct file for filetype "$filetype");
}

# check detailed output
my $expected_info =
  file( qw( t data linked prokaryotes seq-pipelines Actinobacillus pleuropneumoniae TRACKING 607 APP_N1_OP2 SLX APP_N1_OP2_7492554 10018_1#30 544507.se.raw.sorted.bam.expression.csv ) )->stringify
  . "\tStreptococcus_suis_P1_7_v1"
  . "\tsmalt"
  . "\t".'[\d]{4}-[\d]{2}-[\d]{2}T[\d]{2}:[\d]{2}:[\d]{2}'."\n";

$params{details} = 1;
$sf->clear_config;
$sf = Bio::Path::Find::App::PathFind::RNASeq->new(%params);
stdout_like { $sf->run } qr/$expected_info/, 'got expected details';

delete $params{details};

#-------------------------------------------------------------------------------

# check filters

delete $params{filetype};

$params{qc} = 'passed';
$sf->clear_config;
$sf = Bio::Path::Find::App::PathFind::RNASeq->new(%params);
stderr_like { $sf->run }
  qr/No data found/,
  'no data with QC status filter';

delete $params{qc};
$params{mapper} = 'bwa';
$sf->clear_config;
$sf = Bio::Path::Find::App::PathFind::RNASeq->new(%params);
stderr_like { $sf->run }
  qr/No data found/,
  'no data with mapper filter';

delete $params{mapper};
$params{reference} = 'non-existent-reference';
$sf->clear_config;
$sf = Bio::Path::Find::App::PathFind::RNASeq->new(%params);
stderr_like { $sf->run }
  qr/No data found/,
  'no data with reference filter';

delete $params{reference};
$params{ignore_processed_flag} = 1;
$params{id}                    = '10018_1';
$sf->clear_config;
$sf = Bio::Path::Find::App::PathFind::RNASeq->new(%params);

my $expected_file_1 = file( qw( t data linked prokaryotes seq-pipelines Actinobacillus pleuropneumoniae TRACKING 607 APP_N1_OP2 SLX APP_N1_OP2_7492554 10018_1#30 544507.se.raw.sorted.bam.expression.csv ) );

my $expected_output = <<"EOF_files";
$expected_file_1
EOF_files

stdout_is { $sf->run }
  $expected_output,
  'got file with "processed" bit mask filter turned off';

$sf->clear_config;

#-------------------------------------------------------------------------------

# check stats, zip, tar files

$params{id}      = '10018_1#30';
$params{symlink} = 'my_links_dir';
my $tf;
lives_ok { $tf = Bio::Path::Find::App::TestFind->new(%params) }
  'got new testfind app object';
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

$tf->clear_config;

#---------------------------------------

delete $params{archive};
$params{zip} = 'my_zip';

$sf->clear_config;
$sf = Bio::Path::Find::App::PathFind::RNASeq->new(%params);
combined_like { $sf->run }
  qr/Archiving data to 'my_zip'/,
  'got message about writing zip file';

ok -f 'my_zip', 'found zip file';

throws_ok { $sf->run }
  qr/zip archive "my_zip" already exists/,
  'got exception when trying to overwrite zip file';

#---------------------------------------

delete $params{zip};
$params{stats} = 'my_stats';
$params{force} = 1;

$sf->clear_config;
$sf = Bio::Path::Find::App::PathFind::RNASeq->new(%params);
combined_like { $sf->run }
  qr/Wrote statistics to "my_stats"/,
  'got message about writing stats file';

ok -f 'my_stats', 'found stats file';

#-------------------------------------------------------------------------------

# done_testing;

chdir $orig_cwd;

