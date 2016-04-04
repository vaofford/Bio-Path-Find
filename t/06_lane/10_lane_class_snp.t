
use strict;
use warnings;

no warnings 'qw'; # avoid warnings about comments in list when we use lane/plex
                  # IDs in filenames

use Test::More tests => 26;
use Test::Exception;
use Test::Warn;
use Test::Output;
use Path::Class;
use File::Copy;
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

# clone the "pathogen_prok_track.db" SQLite database, so that we can
# modify it without changing the "master copy"
copy file( $orig_cwd, qw( t data pathogen_prok_track.db ) ),
     file( $temp_dir, 'snp_tests.db' );

chdir $temp_dir;

# make sure we can compile the class that we're testing...
use_ok('Bio::Path::Find::Lane::Class::SNP');

#---------------------------------------

# use the Finder to get some lanes to play with
my $config = {
  db_root           => dir(qw( t data linked )),
  connection_params => {
    tracking => {
      driver       => 'SQLite',
      # use the clone of the "pathogen_prok_track.db" SQLite DB
      dbname       => file('snp_tests.db'),
      schema_class => 'Bio::Track::Schema',
    },
  },
  # map the cloned DB to the same set of files on disk
  db_subdirs => {
    snp_tests => 'prokaryotes',
  },
  no_progress_bars => 1,
};

my $finder = Bio::Path::Find::Finder->new(
  config     => $config,
  lane_class => 'Bio::Path::Find::Lane::Class::SNP'
);

# NB lane "10018_1#20" and onwards are specifically set up for these tests

my $lanes;
lives_ok { $lanes = $finder->find_lanes( ids => [ '10018_1#20' ], type => 'lane' ) }
  'no exception when finding lanes';

is scalar @$lanes, 1, 'found one matching lane';

my $lane = $lanes->[0];

isa_ok $lane, 'Bio::Path::Find::Lane';
isa_ok $lane, 'Bio::Path::Find::Lane::Class::SNP';

#-------------------------------------------------------------------------------

# check "_edit_filenames"

my $from = file( qw( path ID 12345_dir file ) );
my $to   = file( qw( path ID 12345_dir ID.12345_dir_file ) );

my ( $src, $dst ) = $lane->_edit_filenames( $from, $from );

is "$src", "$from", '"_edit_filenames" returns source path unchanged';
is "$dst", "$to",   '"_edit_filenames" returns expected destination path';

#-------------------------------------------------------------------------------

# check "get_file_info"

$lane->_get_files('vcf');

my $expected_info = [
  'Streptococcus_suis_P1_7_v1',
  'smalt',
  '2013-07-13T14:39:16',
];

is_deeply $lane->get_file_info($lane->get_file(0)), $expected_info, 'got correct detailed info';

#---------------------------------------

# "print_details"

stdout_is { $lane->print_details }
  file( qw( t data linked prokaryotes seq-pipelines Actinobacillus pleuropneumoniae TRACKING 607 APP_T3_OP1 SLX APP_T3_OP1_7492545 10018_1#20 544213.se.markdup.snp mpileup.unfilt.vcf.gz ) )->stringify
  . "\tStreptococcus_suis_P1_7_v1"
  . "\tsmalt"
  . "\t2013-07-13T14:39:16\n",
  '"print_details" gives expected info';

#-------------------------------------------------------------------------------

# check "_get_files"; looking for a VCF file

is $lane->file_count, 1, 'found one VCF file';
is $lane->get_file(0)->stringify,
  file( qw( t data linked prokaryotes seq-pipelines Actinobacillus pleuropneumoniae TRACKING 607 APP_T3_OP1 SLX APP_T3_OP1_7492545 10018_1#20 544213.se.markdup.snp mpileup.unfilt.vcf.gz ) ),
  'got expected path for VCF file';

$lane->clear_files;
$lane->_get_vcf;
is $lane->file_count, 2, 'found two files using "_get_vcf"';

# looking for a pseudogenome file
$lane->clear_files;
$lane->_get_files('pseudogenome');
is $lane->file_count, 1, 'found one pseudogenome file';
is $lane->get_file(0)->stringify,
  file( qw( t data linked prokaryotes seq-pipelines Actinobacillus pleuropneumoniae TRACKING 607 APP_T3_OP1 SLX APP_T3_OP1_7492545 10018_1#20 544213.se.markdup.snp pseudo_genome.fasta ) ),
  'got expected path for pseudogenome file';

$lane->clear_files;
$lane->_get_pseudogenome;
is $lane->file_count, 1, 'found one file using "_get_pseudogenomes"';
is $lane->get_file(0)->stringify,
  file( qw( t data linked prokaryotes seq-pipelines Actinobacillus pleuropneumoniae TRACKING 607 APP_T3_OP1 SLX APP_T3_OP1_7492545 10018_1#20 544213.se.markdup.snp pseudo_genome.fasta ) ),
  'got expected path for pseudogenome file';

#---------------------------------------

# switch to a different lane, which has a job status file, meaning that it
# should be ignored by the "_get_files" method
$lanes = $finder->find_lanes( ids => [ '10018_1#21' ], type => 'lane' );
$lane = $lanes->[0];
$lane->_get_files('vcf');
ok $lane->has_no_files, 'found no VCF files for lane with job status file';

#---------------------------------------

# filter on mapper
$lanes = $finder->find_lanes(
  ids             => ['10018_1#20'],
  type            => 'lane',
  lane_attributes => { mappers => [ 'bwa' ] },
);
$lane = $lanes->[0];
$lane->_get_files('vcf');
ok $lane->has_no_files, 'found no VCF files mapped with "bwa"';

#---------------------------------------

# single or paired end ?
$lanes = $finder->find_lanes( ids => [ '10018_1#22' ], type => 'lane' );
$lane = $lanes->[0];
$lane->_get_files('vcf');

is $lane->file_count, 1, 'found one VCF file';
is $lane->get_file(0)->stringify,
  file( qw( t data linked prokaryotes seq-pipelines Actinobacillus pleuropneumoniae TRACKING 607 APP_T4_OP1 SLX APP_T4_OP1_7492547 10018_1#22 544156.pe.markdup.snp mpileup.unfilt.vcf.gz ) ),
  'got expected path for paired end VCF file';

#---------------------------------------

# get VCF plus index
$lane->clear_files;
$lane->_get_files('vcf', 'tbi');
is $lane->file_count, 2, 'found two files when looking for index';
like $lane->get_file(0), qr/\.vcf\.gz$/,      'found VCF';
like $lane->get_file(1), qr/\.vcf\.gz\.tbi$/, 'found index';

# test the negative too...
$lane->clear_files;
$lane->_get_files('vcf', 'non-existent');
is $lane->file_count, 1, 'only VCF file found when non-existent index suffix supplied';
like $lane->get_file(0), qr/\.vcf\.gz$/,      'found VCF';

$lane->clear_files;
stderr_like { $lane->_get_files('pseudogenome') }
  qr/couldn't find file/,
  'got warning about missing pseudogenome file';

#-------------------------------------------------------------------------------

# done_testing;

chdir $orig_cwd;

