
use strict;
use warnings;

use Test::More; # tests => 24;
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

# and "_get_files"; looking for a VCF file

$lane->_get_files('vcf');
is $lane->file_count, 1, 'found one VCF file';
is $lane->get_file(0)->stringify,
  file( qw( t data linked prokaryotes seq-pipelines Actinobacillus pleuropneumoniae TRACKING 607 APP_T3_OP1 SLX APP_T3_OP1_7492545 ), '10018_1#20', '544213.se.markdup.snp', 'mpileup.unfilt.vcf.gz' ),
  'got expected path for VCF file';

# get a pseudogenome file
$lane->clear_files;
$lane->_get_files('pseudogenome');
is $lane->file_count, 1, 'found one pseudogenome file';
is $lane->get_file(0)->stringify,
  file( qw( t data linked prokaryotes seq-pipelines Actinobacillus pleuropneumoniae TRACKING 607 APP_T3_OP1 SLX APP_T3_OP1_7492545 ), '10018_1#20', '544213.se.markdup.snp', 'pseudo_genome.fasta' ),
  'got expected path for VCF file';

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
  file( qw( t data linked prokaryotes seq-pipelines Actinobacillus pleuropneumoniae TRACKING 607 APP_T4_OP1 SLX APP_T4_OP1_7492547 ), '10018_1#22', '544156.pe.markdup.snp', 'mpileup.unfilt.vcf.gz' ),
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



$DB::single = 1;

#-------------------------------------------------------------------------------

done_testing;

chdir $orig_cwd;

__END__

#-------------------------------------------------------------------------------

# test the "_get_bam" method

# shouldn't find any files when "is_qc" is true

# for this lane, one of the mapstats rows is already flagged as being a QC
# mapping ("is_qc == 1"). Explicitly set "is_qc" for the other mapstats row too
my $mapstats_row = $lane->row->database->schema->resultset('Mapstat')->find( { mapstats_id => 544477 } );
$mapstats_row->update( { is_qc => 1 } );

warnings_are { $lane->_get_bam } [], 'no warnings from "_get_bam"';
ok $lane->has_no_files, 'no files found when "is_qc" true';

#---------------------------------------

# reset "is_qc". Lane now has one mapstats row with "is_qc == 1", one with
# "is_qc == 0"

$mapstats_row->update( { is_qc  => 0, prefix => '_12345678_1234_' } );

# touch a job status file. If the method finds that file for a given lane, it
# shouldn't return a path to a bam file
$job_status_file->touch;

warnings_are { $lane->_get_bam } [], 'no warnings from "_get_bam"';
ok $lane->has_no_files, 'no files found when job status file exists';

#---------------------------------------

# when there is no job status file, we should find one file for this lane

$job_status_file->remove;

warnings_are { $lane->_get_bam } [], 'no warnings from "_get_bam"';

is $lane->file_count, 1, 'found one file';
is $lane->files->[0],
  't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1/544477.se.markdup.bam',
  'found expected file';

#---------------------------------------

# check the paired end/single end filename distinction

$lane = $lanes->[1];

warnings_are { $lane->_get_bam } [], 'no warnings from "_get_bam"';

is $lane->file_count, 1, 'found one file, flagged as paired end';
is $lane->files->[0],
  't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_2/SLX/APP_IN_2_7492527/10018_1#2/544570.pe.markdup.bam',
  'found expected paired end bam file';

#---------------------------------------

# check that we get a warning if we fall back to the raw file but it doesn't
# exist on disk

$lane = $lanes->[3];

warnings_like { $lane->_get_bam }
  [ { carped => qr/expected to find raw bam/ } ],
  'got warning from "_get_bam" about missing raw file';

is $lane->file_count, 1, 'found one file';
is $lane->files->[0],
  't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_4/SLX/APP_IN_4_7492537/10018_1#4/543937.se.raw.sorted.bam',
  'got expected (missing) raw.sorted.bam file';

#---------------------------------------

# make sure _get_bam works with multiple mapstats rows

$lane = $lanes->[4];

warnings_are { $lane->_get_bam } [], 'no warnings from "_get_bam"';

is $lane->file_count, 2, 'found two files';
is_deeply $lane->files,
  [
    't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N1_OP2/SLX/APP_N1_OP2_7492529/10018_1#5/525342.se.markdup.bam',
    't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N1_OP2/SLX/APP_N1_OP2_7492529/10018_1#5/544510.se.markdup.bam',
  ],
  'got expected file paths';

#-------------------------------------------------------------------------------

# "print_details"

stdout_is { $lanes->[0]->print_details }
  't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1/544477.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:41:22
',
  'got expected details for lane with one mapping';

stdout_is { $lanes->[4]->print_details }
  't/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N1_OP2/SLX/APP_N1_OP2_7492529/10018_1#5/525342.se.markdup.bam	Streptococcus_suis_P1_7_v1	bwa	2013-06-25T10:51:43
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N1_OP2/SLX/APP_N1_OP2_7492529/10018_1#5/544510.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:41:31
',
  'got expected details for lane with two mappings';

#-------------------------------------------------------------------------------

# check the "stats" attribute; calls "_build_stats", which calls "_get_stats_row"

my $expected_stats = [
  [
    607,
    'APP_N2_OP1',
    '10018_1#1',
    47,
    397141,
    18665627,
    'Mapping',
    'Streptococcus_suis_P1_7_v1',
    2007491,
    'smalt',
    544477,
    '1.3',
    '0.0',
    undef,
    '0.10',
    '2.97',
    '0.7',
    '0.4',
    '0.3',
    '0.0',
    undef
  ]
];

is_deeply $lanes->[0]->stats, $expected_stats, 'got expected stats for lane with one mapping';

$expected_stats= [
  [
    607,
    'APP_N1_OP2',
    '10018_1#5',
    47,
    304254,
    14299938,
    'Mapping',
    'Streptococcus_suis_P1_7_v1',
    2007491,
    'bwa',
    525342,
    '0.0',
    '0.0',
    0,
    '0.00',
    '0.00',
    undef,
    undef,
    undef,
    undef,
    undef
  ],
  [
    607,
    'APP_N1_OP2',
    '10018_1#5',
    47,
    304254,
    14299938,
    'Mapping',
    'Streptococcus_suis_P1_7_v1',
    2007491,
    'smalt',
    544510,
    '1.2',
    '0.0',
    undef,
    '0.09',
    '2.47',
    '0.5',
    '0.3',
    '0.2',
    '0.1',
    '0.0'
  ]
];

is_deeply $lanes->[4]->stats, $expected_stats, 'got expected stats for lane with two mappings';

#-------------------------------------------------------------------------------

done_testing;

chdir $orig_cwd;

