
use strict;
use warnings;

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
is $t->environment, 'prod', 'object is in prod environment by default';

$t = Bio::Path::Find::TestClass->new( environment => 'test' );
is $t->environment, 'test', 'object is in test environment when set by argument';

$DB::single = 1;

done_testing;

