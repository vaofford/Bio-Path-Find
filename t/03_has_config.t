
use strict;
use warnings;

#---------------------------------------

package Bio::Path::Find::TestClass;

use Moose;
use namespace::autoclean;

with 'Bio::Path::Find::Role::HasConfig';

#---------------------------------------

package main;

use Test::More;
use Test::Exception;
use Path::Class;

BEGIN {
  $ENV{BPF_TEST_VALUE}  = 'a_value';
  $ENV{PATHFIND_CONFIG} = file( qw( t data 03_has_config test.conf ) );
}

use_ok('Bio::Path::Find::TestClass');

# specify config filename when instantiating
my $t;
lives_ok { $t = Bio::Path::Find::TestClass->new( config_file => file( qw( t data 03_has_config test.conf ) ) ) }
  'got new B::M::F::TestClass object successfully';

my $expected_config = {
  db_root        => file( qw( t data ) ),
  from_env       => 'a_value',
  subdir_mapping => {
    one => 'two',
  },
};

is_deeply $t->config, $expected_config, 'got expected config via attribute';

# get config filename from environment
$t = Bio::Path::Find::TestClass->new;

is_deeply $t->config, $expected_config, 'got expected config via environment variable';

# read a YAML config file
lives_ok { $t = Bio::Path::Find::TestClass->new( config_file => file( qw( t data 03_has_config test.yml ) ) ) }
  'got new B::M::F::TestClass object successfully';

$expected_config = {
  db_root        => file( qw( t data ) ),
  subdir_mapping => {
    one => 'two',
  },
};

is_deeply $t->config, $expected_config, 'got expected config via environment variable';

# check for exception when specified config file doesn't exist
throws_ok { Bio::Path::Find::TestClass->new( config_file => 'non-existent-file' ) }
  qr/doesn't exist/,
  'exception when specified config file does not exist';

# check we can accept a string giving the config filename, as well as a
# Path::Class::File

SKIP: {
  skip "can't check path strings except on unix", 1,
    unless file( qw( t data linked ) )->stringify eq 't/data/linked';

  lives_ok { Bio::Path::Find::TestClass->new( config_file => 't/data/03_has_config/test.conf' ) }
    'no exception when using a string for config filename';
};

done_testing;

