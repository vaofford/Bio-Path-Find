
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Output;
use Path::Class;

# don't initialise l4p here because we want to test that command line logging
# is correctly set up by the AppRole

use_ok('Bio::Path::Find::App::PathFind');

# create a test log file and make sure it isn't already there
my $test_log = file('t/data/12_pathfind/_pathfind_test.log');
$test_log->remove;

# simple find - get samples for a lane
my %params = (
  environment => 'test',
  config_file => 't/data/12_pathfind/test.conf',
  id          => '10018_1',
  type        => 'lane',
);

my $pf;
lives_ok { $pf = Bio::Path::Find::App::PathFind->new(%params) } 'got a new pathfind app object';
isa_ok $pf, 'Bio::Path::Find::App::PathFind', 'pathfind app';
ok $pf->does('Bio::Path::Find::App::Role::AppRole'), 'PathFind class does AppRole';

my $expected_results = file 't/data/12_pathfind/expected_paths.txt';
my $expected = join '', $expected_results->slurp;
stdout_is { $pf->run } $expected, 'got expected paths on STDOUT';

ok -f $test_log, 'test log found';

my @log_lines = $test_log->slurp( chomp => 1 );
is scalar @log_lines, 1, 'got one log entry';

# check symlinking

my $symlink_dir = dir 't/data/12_pathfind/_temp';
$symlink_dir->mkpath;

$params{symlink} = $symlink_dir;

lives_ok { $pf = Bio::Path::Find::App::PathFind->new(%params) }
  'got a pathfind app configured to make symlinks';

lives_ok { $pf->run }
  'no exception when making symlinks';



$DB::single = 1;

done_testing;

$test_log->remove;
$symlink_dir->rmtree;

