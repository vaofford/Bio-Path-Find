
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Output;
use File::Slurper qw( read_text );

use_ok('Bio::Path::Find');

# find lanes using a lane name
my $f;
lives_ok { $f = Bio::Path::Find->new(environment => 'test', config_file => 't/data/07_finder/test.conf') }
  'got a finder';

my $lanes = $f->find(
  id   => '10263_4',
  type => 'lane'
);

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

done_testing;

