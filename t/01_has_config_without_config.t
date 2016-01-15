
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
  delete $ENV{PATHFIND_CONFIG};
}

use_ok('Bio::Path::Find::TestClass');

# config file not specified by environment variable
my $t;
lives_ok { $t = Bio::Path::Find::TestClass->new }
  'no exception when instantiating';

throws_ok {$t->config_file}
  qr/can't determine config file/,
  'exception with accessor and config file unspecified';

# done_testing;

