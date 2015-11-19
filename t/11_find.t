
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Output;
use Path::Class;

# TODO fix this file to make it test Bio::Path::Find
# TODO make $lane->symlink($dest) work as expected

use_ok('Bio::Path::Find');

# create a test log file and make sure it isn't already there
my $test_log = file('t/data/07_finder/_pathfind_test.log');
$test_log->remove;

my $f;
lives_ok { $f = Bio::Path::Find->new(environment => 'test', config_file => 't/data/07_finder/test.conf') }
  'got a Bio::Path::Find object';

done_testing;

__END__

# testing the script role feature
#
# first, there should be an exception when we haven't specified a script role
# but the name of this script, which is used to determine a default, isn't found
# in the <script_roles> mapping in the config
throws_ok { $f->find_lanes( ids => [ '10263_4' ], type => 'lane' ) }
  qr/couldn't find a role for the current script/,
  'exception when script_role not passed and script name is not found in mapping';

ok -e $test_log, 'test log file is created when missing';

# now, with the real name of this script present in the <script_roles> mapping
# in the new config, there should be no exception
$f = Bio::Path::Find::Finder->new(environment => 'test', config_file => 't/data/07_finder/test_with_script_role.conf');

lives_ok { $f->find_lanes( ids => [ '10263_4' ], type => 'lane' ) }
  'no exception when script named in script_roles';

# next, we revert to the original config, which has only the script named
# "pathfind" in the <script_roles> mappings. We shouldn't get an exception
# provided we cheat and explicitly set the name of the script when we
# instantiate the Finder, which allows it to correctly set a default role
# using the mapping
$f = Bio::Path::Find::Finder->new(
  environment  => 'test',
  config_file  => 't/data/07_finder/test.conf',
  _script_name => 'pathfind',
);

lives_ok { $f->find_lanes( id => [ '10263_4' ], type => 'lane' ) }
  'no exception getting default when script named in script_roles';

# check that we get an exception from Moose when we try to apply a role
# that doesn't exist
$f = Bio::Path::Find::Finder->new(
  environment => 'test',
  config_file => 't/data/07_finder/test.conf',
  script_role => 'Some::Non::Existent::Role',
);

throws_ok { $f->find_lanes( ids => [ '10263_4' ], type => 'lane' ) }
  qr/couldn't apply role 'Some::Non::Existent::Role'/,
  'exception when script_role not passed but role does not exist';

# and finally, check that we can explicitly set the name of the role
$f = Bio::Path::Find::Finder->new(
  environment => 'test',
  config_file => 't/data/07_finder/test.conf',
  script_role => 'Bio::Path::Find::Role::PathFind',
);

my $lanes;
lives_ok { $lanes = $f->find_lanes( ids => [ '10263_4' ], type => 'lane' ) }
  'no exception getting default when valid Role name provided';

my @log_lines = $test_log->slurp( chomp => 1 );

is scalar @$lanes, 87, 'found 87 lanes with ID 10263_4';

# filter by QC status
$lanes = $f->find_lanes(
  ids  => [ '10263_4' ],
  type => 'lane',
  qc   => 'failed',
);

is scalar @$lanes, 76, 'found 76 failed lanes with ID 10263_4';

# check paths

# look at directory paths
my $paths = file('t/data/07_finder/lane_10050_2_dir_paths.txt')->slurp;

stdout_is { $f->print_paths( id => '10050_2', type => 'lane' ) }
  $paths,
  'got expected paths for lanes without filetype';

# and file paths, when we're looking for a specific type of file
$paths = file('t/data/07_finder/lane_10050_2_file_paths.txt')->slurp;

stdout_is { $f->print_paths(id => '10050_2', type => 'lane', qc => 'pending', filetype => 'fastq') }
  $paths,
  'got expected paths for fastqs';

# look for lanes from a given study
$lanes = $f->find_lanes(
  ids  => [ 607 ],
  type => 'study',
);

is scalar @$lanes, 50, 'found 50 lanes in study 607';

@log_lines = $test_log->slurp( chomp => 1 );
is scalar @log_lines, 9, 'got 9 test log entries';

done_testing;

$test_log->remove;

