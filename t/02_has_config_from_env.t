
use strict;
use warnings;

#---------------------------------------

package Bio::Path::Find::TestClass;

use Moose;
use namespace::autoclean;

with 'Bio::Path::Find::Role::HasConfig';

#---------------------------------------

package main;

use Test::More tests => 3;
use Test::Exception;
use Config::General;

BEGIN {
  $ENV{PATHFIND_CONFIG} = 'non-existent-file';
}

use_ok('Bio::Path::Find::TestClass');

# non-existent config file specified by environment variable
my $t;
lives_ok { $t = Bio::Path::Find::TestClass->new }
  'no exception when instantiating';

throws_ok {$t->config_file}
  qr/doesn't exist/,
  'exception with accessor and non-existent config file';

# done_testing;

