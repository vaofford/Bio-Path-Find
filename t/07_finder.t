
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Output;
use File::Slurper qw( read_text );
use Path::Class;

use_ok('Bio::Path::Find');

# create a test log file and make sure it isn't already there
my $test_log = file('t/data/07_finder/_pathfind_test.log');
$test_log->remove;

# find lanes using a lane name
my $f;
lives_ok { $f = Bio::Path::Find->new(environment => 'test', config_file => 't/data/07_finder/test.conf') }
  'got a finder';

my $lanes = $f->find(
  id   => '10263_4',
  type => 'lane'
);

ok -e $test_log, 'test log file is created when missing';

my @log_lines = $test_log->slurp( chomp => 1 );
is scalar @log_lines, 1, 'got a log entry';

is scalar @$lanes, 87, 'found 87 lanes with ID 10263_4';

# filter by QC status
$lanes = $f->find(
  id   => '10263_4',
  type => 'lane',
  qc   => 'failed',
);

is scalar @$lanes, 76, 'found 76 failed lanes with ID 10263_4';

# check paths

# look at directory paths
my $paths = read_text('t/data/07_finder/lane_10050_2_dir_paths.txt');

stdout_is { $f->print_paths( id => '10050_2', type => 'lane' ) }
  $paths,
  'got expected paths for lanes without filetype';

# and file paths, when we're looking for a specific type of file
$paths = read_text('t/data/07_finder/lane_10050_2_file_paths.txt');

stdout_is { $f->print_paths(id => '10050_2', type => 'lane', qc => 'pending', filetype => 'fastq') }
  $paths,
  'got expected paths for fastqs';

# look for lanes from a given study
$lanes = $f->find(
  id   => 607,
  type => 'study',
);

is scalar @$lanes, 50, 'found 50 lanes in study 607';

@log_lines = $test_log->slurp( chomp => 1 );
is scalar @log_lines, 5, 'got 5 test log entries';

done_testing;

$test_log->remove;

