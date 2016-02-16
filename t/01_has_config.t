
#---------------------------------------

package Bio::Path::Find::TestClass;

use Moose;
use namespace::autoclean;

with 'Bio::Path::Find::Role::HasConfig';

#---------------------------------------

package main;

use strict;
use warnings;

use Test::More tests => 15;
use Test::Exception;
use Path::Class;

use_ok('Bio::Path::Find::TestClass');

# config from a hash

my $t1;
lives_ok { $t1 = Bio::Path::Find::TestClass->new }
  'no exception when instantiating without config hash';

throws_ok { Bio::Path::Find::TestClass->new( config => {} ) }
  qr/Singleton is already initialized/,
  'exception when instantiating without clearing singleton';

lives_ok { $t1->clear_config }
  'no exception when clearing config';

my %config_hash = (
  one => 1,
  two => [ 2, 3, 4 ],
);

lives_ok { $t1 = Bio::Path::Find::TestClass->new( config => \%config_hash ) }
  'no exception when instantiating with config hash after clearing';

my $t2;
lives_ok { $t2 = Bio::Path::Find::TestClass->new }
  'no exception when instantiating second object, without config';

my $t1_singleton = $t1->config(object => 1);
my $t2_singleton = $t2->config(object => 1);

isa_ok $t1_singleton, 'Bio::Path::Find::ConfigSingleton';

is $t1_singleton, $t2_singleton,
  'config singleton object is same in the two test objects';

is $t1->config, $t2->config,
  'config hashes same in the two test objects';

is_deeply $t1->config, \%config_hash, 'config hash matches';

# config from a string giving the path to a config file

# (clear singleton first)
$t1_singleton->_clear_instance;

my $config_file = file( qw( t data 01_has_config test.conf ) );
lives_ok { $t1 = Bio::Path::Find::TestClass->new( config => $config_file->stringify ) }
  'no exception when getting config from file (string)';

# and from Path::Class::File object giving the path to a config file

# (clear singleton first)
$t1_singleton->_clear_instance;

lives_ok { $t1 = Bio::Path::Find::TestClass->new( config => $config_file ) }
  'no exception when getting config from file (as a Path::Class::File)';

# and from a YAML file, just for good measure

# (clear singleton first)
$t1_singleton->_clear_instance;

$config_file = file( qw( t data 01_has_config test.yaml ) );
lives_ok { $t1 = Bio::Path::Find::TestClass->new( config => $config_file ) }
  'no exception when getting config from YAML file (as a Path::Class::File)';

# check exceptions

$t1_singleton->_clear_instance;

throws_ok { Bio::Path::Find::TestClass->new( config => 'non-existent file path' ) }
  qr/ERROR: can't find config file/,
  'exception when trying to read config from non-existent file path';

throws_ok { Bio::Path::Find::TestClass->new( config => file( qw( t 01_has_config.t ) ) ) }
  qr/There are no loaders available for \.t/,
  'exception when trying to read config from invalid file';

# done_testing;

