
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Warn;
use Try::Tiny;

use_ok('Bio::Path::Find::Database');

my $db;
lives_ok { $db = Bio::Path::Find::Database->new( environment => 'test', name => 'pathogen_prok_track', config_file => 't/data/04_database/test_no_dbname.conf' ) }
  'got a B::P::F::Database object';
throws_ok { $db->_get_dsn }
  qr/must specify SQLite DB location/,
  'exception with configuration having missing dbname';

lives_ok { $db = Bio::Path::Find::Database->new( environment => 'test', name => 'pathogen_prok_track', config_file => 't/data/04_database/test.conf' ) }
  'got a B::P::F::Database object';

my $dsn;
lives_ok { $dsn = $db->_get_dsn } 'no exception getting DSN';

$db = Bio::Path::Find::Database->new(
  environment => 'test',
  name        => 'pathogen_prok_track',
  config_file => 't/data/04_database/test.conf',
);

is $db->_get_dsn, 'dbi:SQLite:dbname=t/data/pathogen_prok_track.db', 'correct DSN in test env';
is $db->db_root, 't/data/linked', 'got expected root directory';
isa_ok $db->schema, 'Bio::Track::Schema', 'schema';

my $broken_db = Bio::Path::Find::Database->new( environment => 'test', name => 'pathogen_prok_track', config_file => 't/data/04_database/test_no_hierarchy_template.conf' );
my $template;
warning_like { $template = $broken_db->hierarchy_template }
  qr/does not specify the directory hierarchy template/,
  'got warning about missing hierarchy template in config';

is $template, 'genus:species-subspecies:TRACKING:projectssid:sample:technology:library:lane',
  'got default template';

warning_is { $template = $db->hierarchy_template } [], 'no warning when template set in config';
is $template, 'genus:species:TRACKING:sample:lane', 'got correct template';

$broken_db = Bio::Path::Find::Database->new( environment => 'test', name => 'pathogen_prok_track', config_file => 't/data/04_database/test_no_mapping.conf' );

my $root;
warning_like { $root = $broken_db->hierarchy_root_dir }
  qr/does not specify the mapping/,
  'warning with config having no subdir mapping';

is $root, 't/data/linked/prokaryotes/seq-pipelines',
  'got correct root dir without subdir';

warning_is { $root = $db->hierarchy_root_dir } [], 'no warning when subdir mapping in config';

is $root, 't/data/linked/prokaryotes/seq-pipelines',
  'got correct root dir';

# check we get a valid DSN for a MySQL DB
$db = Bio::Path::Find::Database->new( environment => 'prod', name => 'pathogen_track_test', config_file => 't/data/04_database/prod_dummy_creds.conf');
is $db->_get_dsn, 'DBI:mysql:host=dbhost;port=3306;database=pathogen_track_test', 'correct DSN in "production"';

# see if we can perform tests on a test DB on a MySQL server
$db = Bio::Path::Find::Database->new( environment => 'prod', name => 'pathogen_track_test', config_file => 't/data/04_database/prod.conf');

isa_ok $db->schema, 'Bio::Track::Schema', 'schema';

SKIP: {
  skip 'no credentials for live DB; set TEST_MYSQL_HOST, TEST_MYSQL_PORT, TEST_MYSQL_USER', 1
    unless ( $ENV{TEST_MYSQL_HOST} and
             $ENV{TEST_MYSQL_PORT} and
             $ENV{TEST_MYSQL_USER} );

  diag 'connecting to MySQL DB';

  lives_ok { $db->schema->resultset('LatestLane')->count }
    'can count rows in lane table';
}

done_testing;

