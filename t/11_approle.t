
package Bio::Path::Find::App::TestFind;

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

with 'Bio::Path::Find::App::Role::AppRole';

sub run {
  my $self = shift;

  $self->log->debug('debug message');

  $self->_log_command;
};

package main;

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Output;
use Path::Class;
use Log::Log4perl;

# don't initialise l4p here because we want to test that command line logging
# is correctly set up by the AppRole

use_ok('Bio::Path::Find::App::TestFind');

# create a test log file and make sure it isn't already there
my $test_log = file('t/data/11_approle/_testfind_test.log');
$test_log->remove;

# simple find - get samples for a lane
my %params = (
  environment => 'test',
  config_file => 't/data/11_approle/test.conf',
  id          => '10018_1',
  type        => 'lane',
);

my $tf;
lives_ok { $tf = Bio::Path::Find::App::TestFind->new(%params) } 'got a new pathfind app object';
isa_ok $tf, 'Bio::Path::Find::App::TestFind', 'pathfind app';

is_deeply $tf->_ids, ['10018_1'], 'IDs set correctly with one ID';
is $tf->type, 'lane', 'type set correctly with ID in parameters';

$tf->run; # all this does is write a log entry

ok -f $test_log, 'test log found';

my @log_lines = $test_log->slurp( chomp => 1 );
is scalar @log_lines, 1, 'got one log entry';

# check that the renamed ID is generated correctly
$params{id} = '10018_1#1';
$tf = Bio::Path::Find::App::TestFind->new(%params);

is $tf->_renamed_id, '10018_1_1', 'renamed ID correctly generated';

# more complicated - get samples for lane IDs in a file
%params = (
  environment  => 'test',
  config_file  => 't/data/11_approle/test.conf',
  id           => 't/data/11_approle/ids.txt',
  type         => 'file',
  file_id_type => 'lane',
  verbose      => 1,
);

$tf = Bio::Path::Find::App::TestFind->new(%params);

# check that the IDs and type have been set correctly
is_deeply $tf->_ids, [ '10018_1', '10263' ], 'got ID list from file';
is $tf->_type, 'lane', 'got ID type as "lane"';

# cheat and re-initialize Log4perl, otherwise the config that we used
# originally won't be overwritten with the new one that has debugging turned on
Log::Log4perl->init($tf->_logger_config);

stderr_like { $tf->run } qr/debug message/, 'found debug message';

done_testing;

$test_log->remove;

