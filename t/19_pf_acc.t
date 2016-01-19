
use strict;
use warnings;

use Test::More tests => 18;
use Test::Exception;
use Test::Output;
use Test::LWP::UserAgent;
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

use_ok('Bio::Path::Find::App::PathFind::Accession');

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
    filereport_url => 'http://some.where',
  },
  id   => '10018_1',
  type => 'lane',
);

# make sure a sensible config and sensible query get us the output we expect
my $af;
lives_ok { $af = Bio::Path::Find::App::PathFind::Accession->new(%params) }
  'got a new Info command object';

# check filereport URI is picked up correctly
isa_ok $af->_filereport_url, 'URI::URL';
is $af->_filereport_url->as_string, 'http://some.where/', 'filereport URL from config is correct';

# remove the URL from the config and make sure we get the expected value
delete $params{config}->{filereport_url};
$af = Bio::Path::Find::App::PathFind::Accession->new(%params);
is $af->_filereport_url->as_string, 'http://www.ebi.ac.uk/ena/data/warehouse/filereport',
  'default filereport URL is correct';

# print paths
my $expected_info = join '', <DATA>;
stdout_is { $af->run }
  $expected_info,
  'printed correct accessions';

#-------------------------------------------------------------------------------

# writing CSV files

$params{outfile} = 'af.csv';
$params{id}      = '10018_1#1';

lives_ok { $af = Bio::Path::Find::App::PathFind::Accession->new(%params) }
  'got a new Accession command object set up to write CSV files';

stderr_like { $af->run } qr/Wrote accessions to "af.csv"/, 'write accessions to CSV file';

# check CSV file contents
my $expected_csv = <<'EOF_csv';
"Sample name","Sample accession","Lane name","Lane accession"
APP_N2_OP1,ERS153571,10018_1#1,"not found"
EOF_csv

my $got_csv = file('af.csv')->slurp;

is $got_csv, $expected_csv, 'got expected CSV contents';

# we should get an error if we try to write the same file again
throws_ok { $af->run }
  qr/ERROR: output file "af.csv" already exists; not overwriting/,
  'exception when trying to overwrite existing CSV';

unlink 'af.csv';

#-------------------------------------------------------------------------------

# writing URL files

# set up a fake LWP::UserAgent to return potted responses. Note that the first
# fastq URL is false; the real request would return "ftp.*sra*.ebi.ac.uk". The
# response URL for "submitted_ftp" is similarly broken.
my $ua = Test::LWP::UserAgent->new;
$ua->map_response(
  qr(fastq_ftp) => HTTP::Response->new( 200, 'OK', undef, 'fastq_ftp
ftp.ebi.ac.uk/vol1/fastq/ERR028/ERR028809/ERR028809_1.fastq.gz;ftp.sra.ebi.ac.uk/vol1/fastq/ERR028/ERR028809/ERR028809_2.fastq.gz'),
);
$ua->map_response(
  qr(submitted_ftp) => HTTP::Response->new( 200, 'OK', undef, 'submitted_ftp
ftp.ebi.ac.uk/vol1/ERA020/ERA020634/srf/5477_6#1.srf'),
);

$params{_ua}   = $ua;           # pass in the fake UA
$params{id}    = '5477_6#1';    # switch to an ID that actually has accessions
$params{fastq} = 'f.txt';

lives_ok { $af = Bio::Path::Find::App::PathFind::Accession->new(%params) }
  'got a new Accession command object set up to write fastq URLs';

stderr_like { $af->run } qr/Wrote ENA URLs for fastq files to "f.txt"/, 'write fastq URLs to file';

# check file contents
my $expected_urls = <<'EOF_urls';
ftp://ftp.ebi.ac.uk/vol1/fastq/ERR028/ERR028809/ERR028809_1.fastq.gz
ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR028/ERR028809/ERR028809_2.fastq.gz
EOF_urls

my $got_urls = file('f.txt')->slurp;

is $got_urls, $expected_urls, 'got expected fastq URLs';

# we should get an error if we try to write the same file again
unlink 'af.csv'; # not interested in the error when this file already exists
throws_ok { $af->run }
  qr/ERROR: fastq URL output file "f\.txt" already exists; not overwriting/,
  'exception when trying to overwrite existing URLs file';

unlink 'af.csv';

#---------------------------------------

# and now URLs for submitted files

delete $params{fastq};
$params{submitted} = 's.txt';

lives_ok { $af = Bio::Path::Find::App::PathFind::Accession->new(%params) }
  'got a new Accession command object set up to write submitted file URLs';

stderr_like { $af->run } qr/Wrote ENA URLs for submitted files to "s.txt"/, 'write submitted file URLs to file';

# check file contents
$expected_urls = <<'EOF_urls';
ftp://ftp.ebi.ac.uk/vol1/ERA020/ERA020634/srf/5477_6#1.srf
EOF_urls

$got_urls = file('s.txt')->slurp;

is $got_urls, $expected_urls, 'got expected fastq URLs';

unlink 'af.csv'; # not interested in the error when this file already exists
throws_ok { $af->run }
  qr/ERROR: submitted URL output file "s\.txt" already exists; not overwriting/,
  'exception when trying to overwrite existing URLs file';

#-------------------------------------------------------------------------------

# done_testing;

chdir $orig_cwd;

__DATA__
Sample name     Sample accession          Lane name                 Lane accession           
APP_N2_OP1      ERS153571                 10018_1#1                 not found                
APP_IN_2        ERS153568                 10018_1#2                 not found                
APP_T1_OP2      ERS153574                 10018_1#3                 not found                
APP_IN_4        ERS153578                 10018_1#4                 not found                
APP_N1_OP2      ERS153570                 10018_1#5                 not found                
APP_N1_OP1      ERS153569                 10018_1#6                 not found                
APP_T1_OP1      ERS153573                 10018_1#7                 not found                
APP_IN_3        ERS153577                 10018_1#8                 not found                
APP_N2_OP2      ERS153572                 10018_1#9                 not found                
APP_IN_1        ERS153567                 10018_1#10                not found                
APP_T2_OP1      ERS153575                 10018_1#11                not found                
APP_T2_OP2      ERS153576                 10018_1#12                not found                
APP_IN_5        ERS153579                 10018_1#13                not found                
APP_N3_OP1      ERS153580                 10018_1#14                not found                
APP_N3_OP2      ERS153581                 10018_1#15                not found                
APP_N4_OP1      ERS153582                 10018_1#16                not found                
APP_N4_OP2      ERS153583                 10018_1#17                not found                
APP_N5_OP1      ERS153584                 10018_1#18                not found                
APP_N5_OP2      ERS153585                 10018_1#19                not found                
APP_T3_OP1      ERS153586                 10018_1#20                not found                
APP_T3_OP2      ERS153587                 10018_1#21                not found                
APP_T4_OP1      ERS153588                 10018_1#22                not found                
APP_T4_OP2      ERS153589                 10018_1#23                not found                
APP_T5_OP1      ERS153590                 10018_1#24                not found                
APP_T5_OP2      ERS153591                 10018_1#25                not found                
APP_IN_1        ERS153567                 10018_1#27                not found                
APP_IN_2        ERS153568                 10018_1#28                not found                
APP_N1_OP1      ERS153569                 10018_1#29                not found                
APP_N1_OP2      ERS153570                 10018_1#30                not found                
APP_N2_OP1      ERS153571                 10018_1#31                not found                
APP_N2_OP2      ERS153572                 10018_1#32                not found                
APP_T1_OP1      ERS153573                 10018_1#33                not found                
APP_T1_OP2      ERS153574                 10018_1#34                not found                
APP_T2_OP1      ERS153575                 10018_1#35                not found                
APP_T2_OP2      ERS153576                 10018_1#36                not found                
APP_IN_3        ERS153577                 10018_1#37                not found                
APP_IN_4        ERS153578                 10018_1#38                not found                
APP_IN_5        ERS153579                 10018_1#39                not found                
APP_N3_OP1      ERS153580                 10018_1#40                not found                
APP_N3_OP2      ERS153581                 10018_1#41                not found                
APP_N4_OP1      ERS153582                 10018_1#42                not found                
APP_N4_OP2      ERS153583                 10018_1#43                not found                
APP_N5_OP1      ERS153584                 10018_1#44                not found                
APP_N5_OP2      ERS153585                 10018_1#45                not found                
APP_T3_OP1      ERS153586                 10018_1#46                not found                
APP_T3_OP2      ERS153587                 10018_1#47                not found                
APP_T4_OP1      ERS153588                 10018_1#48                not found                
APP_T4_OP2      ERS153589                 10018_1#49                not found                
APP_T5_OP1      ERS153590                 10018_1#50                not found                
APP_T5_OP2      ERS153591                 10018_1#51                not found                
