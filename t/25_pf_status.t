
use strict;
use warnings;

use Test::More tests => 10;
use Test::Exception;
use Test::Output;
use Path::Class;
use File::Temp;
use Capture::Tiny qw( capture_stderr );
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
# is correctly set up by the App class

use_ok('Bio::Path::Find::App::PathFind::Status');

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
  id   => '10018_1',
  type => 'lane',
);

# make sure a sensible config and sensible query get us the output we expect
my $sf;
lives_ok { $sf = Bio::Path::Find::App::PathFind::Status->new(%params) }
  'got a new Status command object';

# print status table
my $expected_info = join '', <DATA>;
my ( $stdout, $stderr ) = Test::Output::output_from { $sf->run };
# (not sure why we have to specify a fully qualified function name for
# "output_from", but it doesn't seem to work without the package name.)

is $stdout, $expected_info, 'printed status table is correct';
like $stderr, qr/WARNING: failed to read job status file/,
  'got warning about unreadable job status file';

# write a CSV file

$params{id}      = '10018_1#1';
$params{outfile} = 'sf.csv';
$sf->clear_config;

lives_ok { $sf = Bio::Path::Find::App::PathFind::Status->new(%params) }
  'got a new Status command object set up to write CSV files';

stderr_like { $sf->run } qr/Wrote status information to "sf.csv"/,
  'wrote status info to CSV file';

# check CSV file contents
my $expected_csv = <<'EOF_csv';
Name,Import,QC,Mapping,Archive,Improve,"SNP call",RNASeq,Assemble,Annotate
10018_1#1,Done,Done,Done,Done,-,-,-,-,Done
EOF_csv

my $got_csv = file('sf.csv')->slurp;

is $got_csv, $expected_csv, 'got expected CSV contents';

# we should get an error if we try to write the same file again
throws_ok { $sf->run }
  qr/ERROR: CSV file "sf.csv" already exists; not overwriting existing file/,
  'exception when trying to overwrite existing CSV';

# but not if we set the "force" option

$params{force} = 1;
$params{id}    = '10018_1#2'; # write info for a different lane, so we know
$sf->clear_config;            # that we have actually written something

$sf = Bio::Path::Find::App::PathFind::Status->new(%params);

lives_ok { capture_stderr { $sf->run } } 'no exception when "force" is true';

$expected_csv = <<'EOF_csv';
Name,Import,QC,Mapping,Archive,Improve,"SNP call",RNASeq,Assemble,Annotate
10018_1#2,Done,Done,Done,Done,-,-,-,Done,Done
EOF_csv

$got_csv = file('sf.csv')->slurp;
is $got_csv, $expected_csv, 'got expected CSV contents';

#-------------------------------------------------------------------------------

# done_testing;

chdir $orig_cwd;

__DATA__
Name       Import QC   Mapping             Archive Improve SNP call RNASeq Assemble Annotate
10018_1#1  Done   Done Done                Done    -       -        -      -        Done    
10018_1#2  Done   Done Done                Done    -       -        -      Done     Done    
10018_1#3  Done   Done Done                Done    -       -        -      Done     Done    
10018_1#4  Done   Done Done                Done    -       -        -      -        -       
10018_1#5  Done   Done Done                Done    -       -        -      -        -       
10018_1#6  Done   Done Done                Done    -       -        -      -        -       
10018_1#7  Done   Done Done                Done    -       -        -      -        -       
10018_1#8  Done   Done Done                Done    -       -        -      -        -       
10018_1#9  Done   Done Done                Done    -       -        -      -        -       
10018_1#10 Done   Done Failed (01-01-2015) Done    -       -        -      -        -       
10018_1#11 Done   Done Done                Done    -       -        -      -        -       
10018_1#12 Done   Done Done                Done    -       -        -      -        -       
10018_1#13 Done   Done Done                Done    -       -        -      -        -       
10018_1#14 Done   Done Done                Done    -       -        -      -        -       
10018_1#15 Done   Done Done                Done    -       -        -      -        -       
10018_1#16 Done   Done Done                Done    -       -        -      -        -       
10018_1#17 Done   Done Done                Done    -       -        -      -        -       
10018_1#18 Done   Done Done                Done    -       -        -      -        -       
10018_1#19 Done   Done Done                Done    -       -        -      -        -       
10018_1#20 Done   Done Done                Done    -       -        -      -        -       
10018_1#21 Done   Done Done                Done    -       -        -      -        -       
10018_1#22 Done   Done Done                Done    -       -        -      -        -       
10018_1#23 Done   Done Done                Done    -       -        -      -        -       
10018_1#24 Done   Done Done                Done    -       -        -      -        -       
10018_1#25 Done   Done Done                Done    -       -        -      -        -       
10018_1#27 Done   Done Done                Done    -       -        -      -        -       
10018_1#28 Done   Done Done                Done    -       -        -      -        -       
10018_1#29 Done   Done Done                Done    -       -        -      -        -       
10018_1#30 Done   Done Done                Done    -       -        -      -        -       
10018_1#31 Done   Done Done                Done    -       -        -      -        -       
10018_1#32 Done   Done Done                Done    -       -        -      -        -       
10018_1#33 Done   Done Done                Done    -       -        -      -        -       
10018_1#34 Done   Done Done                Done    -       -        -      -        -       
10018_1#35 Done   Done Done                Done    -       -        -      -        -       
10018_1#36 Done   Done Done                Done    -       -        -      -        -       
10018_1#37 Done   Done Done                Done    -       -        -      -        -       
10018_1#38 Done   Done Done                Done    -       -        -      -        -       
10018_1#39 Done   Done Done                Done    -       -        -      -        -       
10018_1#40 Done   Done Done                Done    -       -        -      -        -       
10018_1#41 Done   Done Done                Done    -       -        -      -        -       
10018_1#42 Done   -    -                   -       -       -        -      -        -       
10018_1#43 -      Done -                   -       -       -        -      -        -       
10018_1#44 -      -    Done                -       -       -        -      -        -       
10018_1#45 -      -    -                   Done    -       -        -      -        -       
10018_1#46 -      -    -                   -       Done    -        -      -        -       
10018_1#47 -      -    -                   -       -       Done     -      -        -       
10018_1#48 -      -    -                   -       -       -        Done   -        -       
10018_1#49 -      -    -                   -       -       -        -      Done     -       
10018_1#50 -      -    -                   -       -       -        -      Done     Done    
10018_1#51 Done   Done Done                Done    -       -        -      Done     -       
