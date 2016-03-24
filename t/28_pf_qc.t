
use strict;
use warnings;

use Test::More tests => 22;
use Test::Exception;
use Test::Output;
use Capture::Tiny ':all';
use Path::Class;
use File::Temp;
use Cwd;
use Text::CSV_XS;

# set up the "linked" directory for the test suite
use lib 't';

use Test::Setup;

unless ( -d dir( qw( t data linked ) ) ) {
  diag 'creating symlink directory';
  Test::Setup::make_symlinks;
}

use Bio::Path::Find::Finder;

# don't initialise l4p here because we want to test that command line logging
# is correctly set up by the App class

use_ok('Bio::Path::Find::App::PathFind::QC');

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
    db_root           => dir( qw( t data linked ) ),
    connection_params => {
      tracking => {
        driver       => 'SQLite',
        dbname       => file( qw( t data pathogen_prok_track.db ) )->stringify,
        schema_class => 'Bio::Track::Schema',
      },
    },
  },
  id   => '10018_1#1',
  type => 'lane',
);

# make sure a sensible config and sensible query get us the output we expect
my $qc;
lives_ok { $qc = Bio::Path::Find::App::PathFind::QC->new(%params) }
  'got a new QC command object';

my $expected_info = "t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1/kraken.report\n";

stdout_is { $qc->run } $expected_info, 'list of reports is correct';

#---------------------------------------

# check archiving (tar file)

my $output = file( $temp_dir, 'output' );
$params{archive} = $output;

$qc->clear_config;
$qc = Bio::Path::Find::App::PathFind::QC->new(%params);

output_like { $qc->run }
  qr/kraken\.report/,              # stdout
  qr/Archiving data to '$output'/, # stderr
  'succeeded in writing tar file';

ok -f $output, 'found tar file on disk';

throws_ok { $qc->run }
  qr/already exists/,
  'exception when trying to write file that already exists';

$params{force} = 1;

$qc->clear_config;
$qc = Bio::Path::Find::App::PathFind::QC->new(%params);

lives_ok { capture_merged { $qc->run } }
  'no exception when overwriting with --force';

#-------------------------------------------------------------------------------

# check zip file generation

unlink $output;

delete $params{archive};
delete $params{force};
$params{zip} = $output;

$qc->clear_config;
$qc = Bio::Path::Find::App::PathFind::QC->new(%params);

output_like { $qc->run }
  qr/kraken\.report/,                # stdout
  qr/Archiving data to '$output'/, # stderr
  'succeeded in writing zip file';

ok -f $output, 'found zip file on disk';

throws_ok { $qc->run }
  qr/already exists/,
  'exception when trying to write file that already exists';

$params{force} = 1;

$qc->clear_config;
$qc = Bio::Path::Find::App::PathFind::QC->new(%params);

lives_ok { capture_merged { $qc->run } }
  'no exception when overwriting with --force';

#-------------------------------------------------------------------------------

# check summary generation, and the switches that affect the report

unlink $output;

delete $params{zip};
delete $params{force};
$params{summary} = $output;

$qc->clear_config;
$qc = Bio::Path::Find::App::PathFind::QC->new(%params);

stderr_like { $qc->run }
  qr/wrote summary as '$output'/,
  'wrote summary';

ok -f $output, 'found summary CSV file';

is_deeply [ file($output)->slurp ],
          [ file( qw( t data 28_pf_qc summary.csv ) )->slurp ],
  'summary looks right';

#---------------------------------------

$params{force}     = 1;
$params{transpose} = 1;

$qc->clear_config;
stderr_like { Bio::Path::Find::App::PathFind::QC->new(%params)->run }
  qr/wrote summary as '$output'/,
  'wrote summary';

is_deeply [ file($output)->slurp ],
          [ file( qw( t data 28_pf_qc summary_transposed.csv ) )->slurp ],
  'transposed summary looks right';

#---------------------------------------

delete $params{transpose};
$params{counts} = 1;

$qc->clear_config;
stderr_like { Bio::Path::Find::App::PathFind::QC->new(%params)->run }
  qr/wrote summary as '$output'/,
  'wrote summary';

is_deeply [ file($output)->slurp ],
          [ file( qw( t data 28_pf_qc summary_counts.csv ) )->slurp ],
  'summary with counts looks right';

#---------------------------------------

delete $params{counts};
$params{directly} = 1;

$qc->clear_config;
stderr_like { Bio::Path::Find::App::PathFind::QC->new(%params)->run }
  qr/wrote summary as '$output'/,
  'wrote summary';

is_deeply [ file($output)->slurp ],
          [ file( qw( t data 28_pf_qc summary_directly.csv ) )->slurp ],
  'summary with directly assigned reads looks right';

#---------------------------------------

delete $params{directly};
$params{level} = 'D';

$qc->clear_config;
stderr_like { Bio::Path::Find::App::PathFind::QC->new(%params)->run }
  qr/wrote summary as '$output'/,
  'wrote summary';

is_deeply [ file($output)->slurp ],
          [ file( qw( t data 28_pf_qc summary_level.csv ) )->slurp ],
  'summary with level == "D" looks right';

#-------------------------------------------------------------------------------

# done_testing;

chdir $orig_cwd;

