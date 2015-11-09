
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Warn;
use Try::Tiny;

use_ok('Bio::Path::Find::DatabaseManager');

my $dbm;
lives_ok { $dbm = Bio::Path::Find::DatabaseManager->new( config_file => 't/data/05_database_manager/no_connection_params.conf') }
  'no exception instantiating with config having no connection parameters';
throws_ok { $dbm->connection_params }
  qr/does not specify any database connection parameters/,
  'exception trying to retrieve connection params';

lives_ok { $dbm = Bio::Path::Find::DatabaseManager->new( config_file => 't/data/05_database_manager/some_connection_params.conf') }
  'no exception instantiating with config having missing connection parameters';
throws_ok { $dbm->connection_params }
  qr/does not specify one of the required database connection parameters/,
  'exception with missing connection params';

lives_ok { $dbm = Bio::Path::Find::DatabaseManager->new( config_file => 't/data/05_database_manager/bad_connection_params.conf') }
  'no exception instantiating with config having invalid connection parameters';
throws_ok { $dbm->data_sources }
  qr/failed to retrieve a list of data sources/,
  "exception with bad database connection params; can't retrieve data sources";

lives_ok { $dbm = Bio::Path::Find::DatabaseManager->new( environment => 'test', config_file => 't/data/05_database_manager/test.conf') }
  'no exception instantiating with test config';
my $ds;
lives_ok { $ds = $dbm->data_sources }
  "no exception building list of test data_sources";

# make sure we get the expected SQLite DB with the test config
is_deeply $ds, [ 'pathogen_test_track' ], 'got expected list of test data sources';

ok scalar keys %{ $dbm->databases }, 'got a Bio::Path::Find::Database object for test DB';

my $db = $dbm->get_database('pathogen_test_track');
isa_ok $db, 'Bio::Path::Find::Database', 'database object';
isa_ok $db->schema, 'Bio::Track::Schema', 'schema';

# use "production" config. Can't easily compare the list of databases, since that's
# liable to change in the test instance
$dbm = Bio::Path::Find::DatabaseManager->new( environment => 'prod', config_file => 't/data/05_database_manager/prod.conf');

SKIP: {
  skip 'no access to live DB; set TEST_MYSQL_HOST, TEST_MYSQL_PORT, TEST_MYSQL_USER', 3
    unless ( $ENV{TEST_MYSQL_HOST} and
             $ENV{TEST_MYSQL_PORT} and
             $ENV{TEST_MYSQL_USER} );

  diag 'connecting to MySQL DB';

  my $can_connect;
  try {
    $can_connect = 1 if $dbm->data_sources;
  } catch {
    $can_connect = 0;
  };

  SKIP: {
    skip "MySQL database tests; check connection params", 3 unless $can_connect;

    lives_ok { $ds = $dbm->data_sources }
      'no exception building list of production data_sources';

    $db = $dbm->get_database('pathogen_test_external');
    isa_ok $db, 'Bio::Path::Find::Database', 'database object';
    isa_ok $db->schema, 'Bio::Track::Schema', 'schema';
  }

}

done_testing;

