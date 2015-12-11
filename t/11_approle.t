
#-------------------------------------------------------------------------------
#- test class ------------------------------------------------------------------
#-------------------------------------------------------------------------------

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

#-------------------------------------------------------------------------------
#- main test package -----------------------------------------------------------
#-------------------------------------------------------------------------------

package main;

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Output;
use Path::Class;
use Cwd;
use Log::Log4perl;
use Text::CSV_XS qw( csv );

# don't initialise l4p here because we want to test that command line logging
# is correctly set up by the AppRole

use_ok('Bio::Path::Find::App::TestFind');

# set up a temp dir where we can write the archive
my $temp_dir = File::Temp->newdir;
dir( $temp_dir, 't' )->mkpath;
my $orig_cwd = getcwd;
symlink( "$orig_cwd/t/data", "$temp_dir/t/data") == 1
  or die "ERROR: couldn't link data directory into temp directory";
chdir $temp_dir;

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

# check CSV writing

my $expected_stats_file         = file(qw( t data 11_approle expected_stats.tsv ));
my $expected_stats_file_content = $expected_stats_file->slurp;
my @expected_stats              = $expected_stats_file->slurp( chomp => 1, split => qr|\t| );

lives_ok { $tf->_write_stats_csv }
  'no exception with no input';

throws_ok { $tf->_write_stats_csv(\@expected_stats) }
  qr/must supply a filename/,
  'exception when no filename';

my $stats_file = file( $temp_dir, 'stats.csv' );
lives_ok { $tf->_write_stats_csv(\@expected_stats, $stats_file) }
  'no exception with valid stats and filename';

# check that we get out exactly what went in
my $stats = csv( in => $stats_file->stringify );
is_deeply $stats, \@expected_stats, 'written contents look right';

throws_ok { $tf->_write_stats_csv(\@expected_stats, $stats_file) }
  qr/not overwriting/,
  'exception when file already exists';

$stats_file->remove;

# write the same data but with a tab separator
$tf->csv_separator("\t");
lives_ok { $tf->_write_stats_csv(\@expected_stats, $stats_file) }
  'no exception writing tab-separated data';

$stats = csv( in => $stats_file->stringify, sep => "\t" );
is_deeply $stats, \@expected_stats, 'tab-separated contents look right';

done_testing;

chdir $orig_cwd;

