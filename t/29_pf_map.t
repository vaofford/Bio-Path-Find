
use strict;
use warnings;

use Test::More tests => 9;
use Test::Exception;
use Test::Output;
use Test::Warn;
use Capture::Tiny qw( capture_stdout capture );
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

use_ok('Bio::Path::Find::App::PathFind::Map');

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
  },
  no_progress_bars => 1,
  id               => '10018_1',
  type             => 'lane',
);

# make sure a sensible config and sensible query get us the output we expect
my $mf;
lives_ok { $mf = Bio::Path::Find::App::PathFind::Map->new(%params) }
  'got a new map command object';

my $bam = "t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_2/SLX/APP_IN_2_7492527/10018_1#2/544570.pe.markdup.bam\n";

my $stdout;
warnings_like { $stdout = capture_stdout { $mf->run } }
  [
    { carped => qr/WARNING: expected to find raw bam file/ },
    { carped => qr/WARNING: expected to find raw bam file/ },
  ],
  'got expected warnings about missing file from "run"';

like $stdout, qr/$bam/, 'got sensible list of bam files';
# (this run uses Lane::Class::Map::print_paths, so we've tested that implicitly)

my @files = split m/\n/, $stdout;
is scalar @files, 39, 'got expected number of bam files';

#---------------------------------------

$params{mapper} = 'bwa';

$mf->clear_config;
$mf = Bio::Path::Find::App::PathFind::Map->new(%params);

$stdout = capture_stdout { $mf->run };
@files = split m/\n/, $stdout;
is scalar @files, 1, 'got single bam file mapped with "bwa"';

#---------------------------------------

delete $params{mapper};
$params{reference} = 'Streptococcus_pneumoniae_ATCC_700669_v1';

$mf->clear_config;
$mf = Bio::Path::Find::App::PathFind::Map->new(%params);

$stdout = capture_stdout { $mf->run };
@files = split m/\n/, $stdout;
is scalar @files, 1, 'got single bam file mapped to specific reference';

#---------------------------------------

# test Lane::Class::Map::print_details

delete $params{reference};
$params{details} = 1;

$mf->clear_config;
$mf = Bio::Path::Find::App::PathFind::Map->new(%params);

# "capture" returns stdout, stderr, and return values. We only care about
# stdout here
( $stdout ) = capture { $mf->run };
@files = split m/\n/, $stdout;
is scalar @files, 39, 'got expected bam files';

my $expected_stdout = join '', <DATA>;

is $stdout, $expected_stdout, 'got expected details';

#-------------------------------------------------------------------------------

# done_testing;

chdir $orig_cwd;

__END__
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_2/SLX/APP_IN_2_7492527/10018_1#2/544570.pe.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:41:47
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T1_OP2/SLX/APP_T1_OP2_7492533/10018_1#3/544387.se.raw.sorted.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:40:51
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_4/SLX/APP_IN_4_7492537/10018_1#4/543937.se.raw.sorted.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:36:19
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N1_OP2/SLX/APP_N1_OP2_7492529/10018_1#5/525342.se.markdup.bam	Streptococcus_suis_P1_7_v1	bwa	2013-06-25T10:51:43
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N1_OP2/SLX/APP_N1_OP2_7492529/10018_1#5/544510.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:41:31
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N1_OP1/SLX/APP_N1_OP1_7492528/10018_1#6/550038.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-17T03:46:00
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T1_OP1/SLX/APP_T1_OP1_7492532/10018_1#7/544414.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:41:02
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_3/SLX/APP_IN_3_7492536/10018_1#8/543970.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:36:40
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP2/SLX/APP_N2_OP2_7492531/10018_1#9/544432.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:41:08
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T2_OP2/SLX/APP_T2_OP2_7492535/10018_1#12/543997.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:36:59
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_5/SLX/APP_IN_5_7492538/10018_1#13/543901.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:35:53
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N3_OP1/SLX/APP_N3_OP1_7492539/10018_1#14/543868.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:35:32
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N3_OP2/SLX/APP_N3_OP2_7492540/10018_1#15/543838.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:35:05
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N4_OP1/SLX/APP_N4_OP1_7492541/10018_1#16/544345.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:40:29
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N4_OP2/SLX/APP_N4_OP2_7492542/10018_1#17/544306.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:40:08
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N5_OP1/SLX/APP_N5_OP1_7492543/10018_1#18/544264.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:39:46
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N5_OP2/SLX/APP_N5_OP2_7492544/10018_1#19/544249.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:39:37
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T3_OP1/SLX/APP_T3_OP1_7492545/10018_1#20/544213.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:39:16
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T4_OP1/SLX/APP_T4_OP1_7492547/10018_1#22/544156.pe.raw.sorted.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:38:43
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T4_OP2/SLX/APP_T4_OP2_7492548/10018_1#23/544117.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:38:18
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T5_OP1/SLX/APP_T5_OP1_7492549/10018_1#24/553870.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-17T13:38:12
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T5_OP2/SLX/APP_T5_OP2_7492550/10018_1#25/544063.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:37:38
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_1/SLX/APP_IN_1_7492551/10018_1#27/544045.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:37:30
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_2/SLX/APP_IN_2_7492552/10018_1#28/544576.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:41:49
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N1_OP1/SLX/APP_N1_OP1_7492553/10018_1#29/544531.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:41:37
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N1_OP2/SLX/APP_N1_OP2_7492554/10018_1#30/544507.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:41:30
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492555/10018_1#31/544474.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:41:21
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP2/SLX/APP_N2_OP2_7492556/10018_1#32/544444.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:41:12
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T1_OP1/SLX/APP_T1_OP1_7492557/10018_1#33/526404.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-06-25T21:17:19
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T1_OP2/SLX/APP_T1_OP2_7492558/10018_1#34/526401.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-06-25T21:17:17
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T2_OP1/SLX/APP_T2_OP1_7492559/10018_1#35/544363.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:40:37
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T2_OP2/SLX/APP_T2_OP2_7492560/10018_1#36/544000.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:37:01
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_3/SLX/APP_IN_3_7492561/10018_1#37/526389.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-06-25T21:17:08
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_4/SLX/APP_IN_4_7492562/10018_1#38/543940.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:36:22
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_5/SLX/APP_IN_5_7492563/10018_1#39/543904.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:35:55
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N3_OP1/SLX/APP_N3_OP1_7492564/10018_1#40/543859.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:35:26
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N3_OP2/SLX/APP_N3_OP2_7492565/10018_1#41/543826.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:34:51
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N5_OP1/SLX/APP_N5_OP1_7492568/10018_1#44/544279.se.markdup.bam	Streptococcus_suis_P1_7_v1	smalt	2013-07-13T14:39:54
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T5_OP2/SLX/APP_T5_OP2_7492575/10018_1#51/544054.se.markdup.bam	Streptococcus_pneumoniae_ATCC_700669_v1	smalt	2013-07-13T14:37:33
