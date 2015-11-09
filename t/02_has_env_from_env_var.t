
use strict;
use warnings;

BEGIN: {
  $ENV{TEST_PATHFIND} = 1;
}

#---------------------------------------

package Bio::Path::Find::TestClass;

use Moo;

with 'Bio::Path::Find::Role::HasEnvironment';

#---------------------------------------

package main;

use Test::More;
use Test::Exception;

use_ok('Bio::Path::Find::TestClass');

my $t = Bio::Path::Find::TestClass->new;
is $t->environment, 'test', 'object is in test environment when set by environment variable';

$t = Bio::Path::Find::TestClass->new( environment => 'prod' );
is $t->environment, 'prod', 'object is in test environment when set by argument';

done_testing;

