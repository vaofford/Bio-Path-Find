

use strict;
use warnings;

use Test::More tests => 13;
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

use_ok('Bio::Path::Find::App::PathFind::Supplementary');

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
      sequencescape => {
        driver       => 'SQLite',
        dbname       => file( qw( t data sequencescape_warehouse.db ) )->stringify,
        schema_class => 'Bio::Sequencescape::Schema',
        no_db_root   => 1,
      },
    },
  },
  id   => '10018_1',
  type => 'lane',
);

# make sure a sensible config and sensible query get us the output we expect
my $sp;
lives_ok { $sp = Bio::Path::Find::App::PathFind::Supplementary->new(%params) }
  'got a new Supplementary command object';

# print paths
my $expected_info = join '', <DATA>;

stdout_is { $sp->run }
  $expected_info,
  'printed correct info';

#-------------------------------------------------------------------------------

# make sure that changing the name of the config section works
my $ss = $params{config}->{connection_params}->{sequencescape};
delete $params{config}->{connection_params}->{sequencescape};
$params{config}->{connection_params}->{ss} = $ss;

$params{sequencescape_schema_name} = 'ss';

# clear config or we'll get errors about re-initializing singletons
$sp->clear_config;

lives_ok { $sp = Bio::Path::Find::App::PathFind::Supplementary->new(%params) }
  'got a new Supplementary command object with different name for SS DB config';

stdout_is { $sp->run }
  $expected_info,
  'printed correct info';

#-------------------------------------------------------------------------------

# writing CSV files

$params{outfile} = 'sp.csv';
$params{id}      = '10018_1#1';
$sp->clear_config;

lives_ok { $sp = Bio::Path::Find::App::PathFind::Supplementary->new(%params) }
  'got a new Supplementary command object set up to write CSV files';

stderr_like { $sp->run } qr/Wrote supplememtary information to "sp.csv"/, 'write supplementary information to CSV file';

# check CSV file contents
my $expected_csv = <<'EOF_csv';
"Sample Name","Sample Acc","Lane Name","Lane Acc","Supplier Name","Public Name",Strain,"Study ID","Study Accession"
APP_N2_OP1,ERS153571,10018_1#1,"not found",NA,APP_N2_OP1,NA,607,ERP000714
EOF_csv

my $got_csv = file('sp.csv')->slurp;
is $got_csv, $expected_csv, 'got expected CSV contents';

# we should get an error if we try to write the same file again
throws_ok { $sp->run }
  qr/ERROR: CSV file "sp.csv" already exists; not overwriting existing file/,
  'exception when trying to overwrite existing CSV';

#-------------------------------------------------------------------------------

# include sample description 

$params{outfile} = '';
$params{description}  = 1;
$sp->clear_config;

lives_ok { $sp = Bio::Path::Find::App::PathFind::Supplementary->new(%params) }
  'got a new Supplementary command object set up to include sample description';

my $expected_description_info = "Sample Name               Sample Acc      Lane Name       Lane Acc        Supplier Name             Public Name               Strain                    Study ID        Study Accession Sample Description
APP_N2_OP1                ERS153571       10018_1#1       not found       NA                        APP_N2_OP1                NA                        607             ERP000714       test sample description
";

stdout_is { $sp->run }
  $expected_description_info,
  'printed correct decription info'; 

#-------------------------------------------------------------------------------
$params{id}      = '10018_1#10';
$params{description}  = 1;
$sp->clear_config;

lives_ok { $sp = Bio::Path::Find::App::PathFind::Supplementary->new(%params) }
  'got a new Supplementary command object set up to include sample description';

$expected_description_info = "Sample Name               Sample Acc      Lane Name       Lane Acc        Supplier Name             Public Name               Strain                    Study ID        Study Accession Sample Description
APP_IN_1                  ERS153567       10018_1#10      not found       NA                        APP_IN_1                  NA                        607             ERP000714       NA
";

stdout_is { $sp->run }
  $expected_description_info,
  'printed correct decription info with null description'; 

#-------------------------------------------------------------------------------

# done_testing;

chdir $orig_cwd;

__DATA__
Sample Name               Sample Acc      Lane Name       Lane Acc        Supplier Name             Public Name               Strain                    Study ID        Study Accession
APP_N2_OP1                ERS153571       10018_1#1       not found       NA                        APP_N2_OP1                NA                        607             ERP000714
APP_IN_2                  ERS153568       10018_1#2       not found       NA                        APP_IN_2                  NA                        607             ERP000714
APP_T1_OP2                ERS153574       10018_1#3       not found       NA                        APP_T1_OP2                NA                        607             ERP000714
APP_IN_4                  ERS153578       10018_1#4       not found       NA                        APP_IN_4                  NA                        607             ERP000714
APP_N1_OP2                ERS153570       10018_1#5       not found       NA                        APP_N1_OP2                NA                        607             ERP000714
APP_N1_OP1                ERS153569       10018_1#6       not found       NA                        APP_N1_OP1                NA                        607             ERP000714
APP_T1_OP1                ERS153573       10018_1#7       not found       NA                        APP_T1_OP1                NA                        607             ERP000714
APP_IN_3                  ERS153577       10018_1#8       not found       NA                        APP_IN_3                  NA                        607             ERP000714
APP_N2_OP2                ERS153572       10018_1#9       not found       NA                        APP_N2_OP2                NA                        607             ERP000714
APP_IN_1                  ERS153567       10018_1#10      not found       NA                        APP_IN_1                  NA                        607             ERP000714
APP_T2_OP1                ERS153575       10018_1#11      not found       NA                        APP_T2_OP1                NA                        607             ERP000714
APP_T2_OP2                ERS153576       10018_1#12      not found       NA                        APP_T2_OP2                NA                        607             ERP000714
APP_IN_5                  ERS153579       10018_1#13      not found       NA                        APP_IN_5                  NA                        607             ERP000714
APP_N3_OP1                ERS153580       10018_1#14      not found       NA                        APP_N3_OP1                NA                        607             ERP000714
APP_N3_OP2                ERS153581       10018_1#15      not found       NA                        APP_N3_OP2                NA                        607             ERP000714
APP_N4_OP1                ERS153582       10018_1#16      not found       NA                        APP_N4_OP1                NA                        607             ERP000714
APP_N4_OP2                ERS153583       10018_1#17      not found       NA                        APP_N4_OP2                NA                        607             ERP000714
APP_N5_OP1                ERS153584       10018_1#18      not found       NA                        APP_N5_OP1                NA                        607             ERP000714
APP_N5_OP2                ERS153585       10018_1#19      not found       NA                        APP_N5_OP2                NA                        607             ERP000714
APP_T3_OP1                ERS153586       10018_1#20      not found       NA                        APP_T3_OP1                NA                        607             ERP000714
APP_T3_OP2                ERS153587       10018_1#21      not found       NA                        APP_T3_OP2                NA                        607             ERP000714
APP_T4_OP1                ERS153588       10018_1#22      not found       NA                        APP_T4_OP1                NA                        607             ERP000714
APP_T4_OP2                ERS153589       10018_1#23      not found       NA                        APP_T4_OP2                NA                        607             ERP000714
APP_T5_OP1                ERS153590       10018_1#24      not found       NA                        APP_T5_OP1                NA                        607             ERP000714
APP_T5_OP2                ERS153591       10018_1#25      not found       NA                        APP_T5_OP2                NA                        607             ERP000714
APP_IN_1                  ERS153567       10018_1#27      not found       NA                        APP_IN_1                  NA                        607             ERP000714
APP_IN_2                  ERS153568       10018_1#28      not found       NA                        APP_IN_2                  NA                        607             ERP000714
APP_N1_OP1                ERS153569       10018_1#29      not found       NA                        APP_N1_OP1                NA                        607             ERP000714
APP_N1_OP2                ERS153570       10018_1#30      not found       NA                        APP_N1_OP2                NA                        607             ERP000714
APP_N2_OP1                ERS153571       10018_1#31      not found       NA                        APP_N2_OP1                NA                        607             ERP000714
APP_N2_OP2                ERS153572       10018_1#32      not found       NA                        APP_N2_OP2                NA                        607             ERP000714
APP_T1_OP1                ERS153573       10018_1#33      not found       NA                        APP_T1_OP1                NA                        607             ERP000714
APP_T1_OP2                ERS153574       10018_1#34      not found       NA                        APP_T1_OP2                NA                        607             ERP000714
APP_T2_OP1                ERS153575       10018_1#35      not found       NA                        APP_T2_OP1                NA                        607             ERP000714
APP_T2_OP2                ERS153576       10018_1#36      not found       NA                        APP_T2_OP2                NA                        607             ERP000714
APP_IN_3                  ERS153577       10018_1#37      not found       NA                        APP_IN_3                  NA                        607             ERP000714
APP_IN_4                  ERS153578       10018_1#38      not found       NA                        APP_IN_4                  NA                        607             ERP000714
APP_IN_5                  ERS153579       10018_1#39      not found       NA                        APP_IN_5                  NA                        607             ERP000714
APP_N3_OP1                ERS153580       10018_1#40      not found       NA                        APP_N3_OP1                NA                        607             ERP000714
APP_N3_OP2                ERS153581       10018_1#41      not found       NA                        APP_N3_OP2                NA                        607             ERP000714
APP_N4_OP1                ERS153582       10018_1#42      not found       NA                        APP_N4_OP1                NA                        607             ERP000714
APP_N4_OP2                ERS153583       10018_1#43      not found       NA                        APP_N4_OP2                NA                        607             ERP000714
APP_N5_OP1                ERS153584       10018_1#44      not found       NA                        APP_N5_OP1                NA                        607             ERP000714
APP_N5_OP2                ERS153585       10018_1#45      not found       NA                        APP_N5_OP2                NA                        607             ERP000714
APP_T3_OP1                ERS153586       10018_1#46      not found       NA                        APP_T3_OP1                NA                        607             ERP000714
APP_T3_OP2                ERS153587       10018_1#47      not found       NA                        APP_T3_OP2                NA                        607             ERP000714
APP_T4_OP1                ERS153588       10018_1#48      not found       NA                        APP_T4_OP1                NA                        607             ERP000714
APP_T4_OP2                ERS153589       10018_1#49      not found       NA                        APP_T4_OP2                NA                        607             ERP000714
APP_T5_OP1                ERS153590       10018_1#50      not found       NA                        APP_T5_OP1                NA                        607             ERP000714
APP_T5_OP2                ERS153591       10018_1#51      not found       NA                        APP_T5_OP2                NA                        607             ERP000714
