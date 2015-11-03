
use strict;
use warnings;

use Test::More;
use Test::Exception;

use_ok('Bio::Path::Find');

my $f;
lives_ok { $f = Bio::Path::Find->new(environment => 'test', config_file => 't/data/07_finder/test.conf') }
  'got a finder';

# TODO this needs way more test cases

$DB::single = 1;

done_testing;

