
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Output;
use File::Slurper qw( read_text );
use Path::Class;

use_ok('Bio::Path::Find');

# find files in production mode, so that we can check that the log file name is
# correctly set according to environment
my $prod_log = file('t/data/07_finder/_pathfind.log');
$prod_log->remove;

SKIP: {
  skip 'no access to live DB; set TEST_MYSQL_HOST, TEST_MYSQL_PORT, TEST_MYSQL_USER', 2
    unless ( $ENV{TEST_MYSQL_HOST} and
             $ENV{TEST_MYSQL_PORT} and
             $ENV{TEST_MYSQL_USER} );

  diag 'connecting to MySQL DB';

  my $f;
  lives_ok { $f = Bio::Path::Find->new(environment => 'prod', config_file => 't/data/07_finder/prod.conf') }
    'got a finder in production mode';

  my $lanes = $f->find(
    id   => '10263_4',
    type => 'lane'
  );

  my @log_lines = $prod_log->slurp( chomp => 1 );
  is scalar @log_lines, 1, 'got a log entry for production mode log';
}

done_testing;

$prod_log->remove;

