
use strict;
use warnings;

no warnings 'qw'; # don't warn about comments in lists when we put plux IDs
                  # inside qw( )

use Test::More tests => 17;
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

use_ok('Bio::Path::Find::App::PathFind::SNP');

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
    refs_index => file( qw( t data 30_pf_snp refs.index ) )->stringify,
    refs_root  => file( qw( t data 30_pf_snp            ) )->stringify,
  },
  no_progress_bars => 1,
  id               => '10018_1#20',
  type             => 'lane',
);

# make sure a sensible config and sensible query get us the output we expect
my $sf;
lives_ok { $sf = Bio::Path::Find::App::PathFind::SNP->new(%params) }
  'got a new snp command object';

#-------------------------------------------------------------------------------

# get VCF files

my @files = (
  file( qw ( t data linked prokaryotes seq-pipelines Actinobacillus pleuropneumoniae TRACKING 607 APP_T3_OP1 SLX APP_T3_OP1_7492545 10018_1#20 544213.se.markdup.snp mpileup.unfilt.vcf.gz ) )->stringify,
  file( qw ( t data linked prokaryotes seq-pipelines Actinobacillus pleuropneumoniae TRACKING 607 APP_T3_OP1 SLX APP_T3_OP1_7492545 10018_1#20 544213.se.markdup.snp mpileup.unfilt.vcf.gz.tbi ) )->stringify,
);

stdout_is { $sf->run } join( "\n", @files ) . "\n",
  'got expected list of VCF/index files';

#---------------------------------------

# detailed output

$params{details} = 1;

$sf->clear_config;
$sf = Bio::Path::Find::App::PathFind::SNP->new(%params);

my $expected_info =
  file( qw ( t data linked prokaryotes seq-pipelines Actinobacillus pleuropneumoniae TRACKING 607 APP_T3_OP1 SLX APP_T3_OP1_7492545 10018_1#20 544213.se.markdup.snp mpileup.unfilt.vcf.gz ) )->stringify
  . "\tStreptococcus_suis_P1_7_v1"
  . "\tsmalt"
  . "\t2013-07-13T14:39:16\n"
  . file( qw ( t data linked prokaryotes seq-pipelines Actinobacillus pleuropneumoniae TRACKING 607 APP_T3_OP1 SLX APP_T3_OP1_7492545 10018_1#20 544213.se.markdup.snp mpileup.unfilt.vcf.gz.tbi ) )->stringify
  . "\tStreptococcus_suis_P1_7_v1"
  . "\tsmalt"
  . "\t2013-07-13T14:39:16\n";

stdout_is { $sf->run } $expected_info, 'got expected detailed info';

#---------------------------------------

# check filtering

# QC status
$params{details} = 0;
$params{qc}      = 'passed';

$sf->clear_config;
$sf = Bio::Path::Find::App::PathFind::SNP->new(%params);

stderr_is { $sf->run } "No data found.\n", 'no data when requiring QC pass';

# mapper
delete $params{qc};
$params{mapper} = 'bwa';

$sf->clear_config;
$sf = Bio::Path::Find::App::PathFind::SNP->new(%params);

stderr_is { $sf->run } "No data found.\n", 'no data when filtering on mapper';

# reference
delete $params{mapper};
$params{reference} = 'non-existent reference';

$sf->clear_config;
$sf = Bio::Path::Find::App::PathFind::SNP->new(%params);

stderr_is { $sf->run } "No data found.\n", 'no data when filtering on reference';

#-------------------------------------------------------------------------------

# check the "_collect_filenames" method

delete $params{reference};

$sf->clear_config;
$sf = Bio::Path::Find::App::PathFind::SNP->new(%params);

my $lanes = $sf->_finder->find_lanes(
  ids      => ['10018_1#20'],
  type     => 'lane',
  filetype => 'vcf',
);

my $dir = dir( qw( t data linked prokaryotes seq-pipelines Actinobacillus pleuropneumoniae TRACKING 607 APP_T3_OP1 SLX APP_T3_OP1_7492545 10018_1#20 544213.se.markdup.snp ) );
my $expected_from_vcf_file = file( $dir, 'mpileup.unfilt.vcf.gz' );
my $expected_from_tbi_file = file( $dir, 'mpileup.unfilt.vcf.gz.tbi' );
my $expected_to_vcf_file   = file( $dir, '10018_1#20.544213_mpileup.unfilt.vcf.gz' );
my $expected_to_tbi_file   = file( $dir, '10018_1#20.544213_mpileup.unfilt.vcf.gz.tbi' );

my $got_filenames = $sf->_collect_filenames($lanes);
my $expected_filenames = [
  { $expected_from_vcf_file->stringify => $expected_to_vcf_file },
  { $expected_from_tbi_file->stringify => $expected_to_tbi_file },
];

is_deeply $got_filenames, $expected_filenames,
  'got expected filenames from "_collect_filenames"';

#-------------------------------------------------------------------------------

# check "_collect_sequences"

$lanes = $sf->_finder->find_lanes(
  ids      => ['10018_1#20'],
  type     => 'lane',
  filetype => 'pseudogenome',
);

my $expected_pseudogenomes = {
  Streptococcus_suis_P1_7_v1 => [
    {
      file => file($dir, 'pseudo_genome.fasta'),
      lane => $lanes->[0],
      mapper => 'smalt',
      ref => 'Streptococcus_suis_P1_7_v1',
      timestamp => '2013-07-13T14:39:16',
    },
  ],
};

my $got_pseudogenomes = $sf->_collect_sequences($lanes);

is_deeply $got_pseudogenomes, $expected_pseudogenomes,
  'got expected data structure from "_collect_sequences"';

#-------------------------------------------------------------------------------

# check "_write_pseudogenomes"

$params{pseudogenome} = 1;

$sf->clear_config;
$sf = Bio::Path::Find::App::PathFind::SNP->new(%params);

my $aln_file = file '10018_1_20_Streptococcus_suis_P1_7_v1_concatenated.aln';

stderr_is { $sf->_write_pseudogenomes($got_pseudogenomes) }
  qq(wrote "$aln_file"\n),
  'got expected pseudogenome file from "_write_pseudogenomes"';

ok -f $aln_file, 'found aln file';

my $expected_contents = <<'EOF_expected_contents';
>Streptococcus_suis_P1_7_v1
atgcatgcatgcatgcatgcatgcatgcatgc
>pseudogenome sequence
cgtacgtacgtacgtacgtacgtacgtacgta
EOF_expected_contents

my $got_contents = join '', $aln_file->slurp;

is $got_contents, $expected_contents,
  'got expected pseudogenome sequences from "_write_pseudogenome"';

# clean up...
$aln_file->remove;

#---------------------------------------

# get pseudogenome files from "_create_pseudogenomes"

$sf->clear_config;
$sf = Bio::Path::Find::App::PathFind::SNP->new(%params);

stderr_is { $sf->run }
  qq(wrote "$aln_file"\n),
  'got expected pseudogenome file from "_create_pseudogenomes"';

ok -f $aln_file, 'found aln file';

$got_contents = join '', $aln_file->slurp;

is $got_contents, $expected_contents,
  'got expected pseudogenome sequences from "_create_pseudogenomes"';

#---------------------------------------

# excluding reference sequences from output alignment

$sf->clear_config;
$sf = Bio::Path::Find::App::PathFind::SNP->new(%params);

throws_ok { $sf->run }
  qr/already exists/,
  'got error about overwriting';

$params{exclude_reference} = 1;

$sf->clear_config;
$sf = Bio::Path::Find::App::PathFind::SNP->new(%params);

$aln_file->remove;
stderr_like { $sf->run }
  qr/omitting reference/,
  'got message about omitting reference';

#-------------------------------------------------------------------------------

# done_testing;

chdir $orig_cwd;

