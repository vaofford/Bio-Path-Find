
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Warn;
use Try::Tiny;

use Bio::Path::Find::Path;

use_ok('Bio::Path::Find::Database');

# make sure we can't instantiate the object with unknown arguments
throws_ok { Bio::Path::Find::Database->new(unknown => 'attr') }
  qr/Found unknown attribute/,
  "can't instantiate with unknown argument";

#---------------------------------------

# try a config with missing production_db values
my $d;
lives_ok { $d = Bio::Path::Find::Database->new(environment => 'test', config_file => 't/data/05_find_database/no_dbs.conf') }
  'got new B::M::F::Database object successfully';
warning_like { $d->production_dbs }
  qr/does not specify the list of production databases/,
  'got warning about missing DBs in config';

# these are the defaults
my $expected_dbs = [ qw(
  pathogen_pacbio_track
  pathogen_prok_track
  pathogen_euk_track
  pathogen_virus_track
  pathogen_helminth_track
) ];
is_deeply $d->production_dbs, $expected_dbs, 'go production DBs from test config';

#---------------------------------------

# test config

$expected_dbs = [ qw(
  pathogen_virus_track
  pathogen_prok_track
) ];

my $expected_connection = {
  dbname => 't/data/05_find_database/test.db',
  host   => 'test_db_host',
  port   => 3306,
  user   => 'ro_user',
  pass   => 'password',
};

$d = Bio::Path::Find::Database->new(environment => 'test', config_file => 't/data/05_find_database/test.conf');
is_deeply $d->production_dbs,           $expected_dbs,           'got expected production DBs from test config';
is_deeply $d->connection_params,        $expected_connection,    'got expected connection params from test config';
is_deeply $d->data_sources,             ['pathogen_test_track'], 'got expected data source in test mode';
is_deeply $d->available_database_names, ['pathogen_test_track'], 'got expected list of names of available databases in test mode';

is $d->get_schema('no_such_db'), undef, 'got undef for unknown schema';

my $schema;
lives_ok { $schema = $d->get_schema('pathogen_test_track') }
  'got schema successfully';
isa_ok $schema, 'Bio::Track::Schema', 'schema';
isa_ok $schema, 'DBIx::Class::Schema', 'schema';

my $schemas = $d->available_database_schemas;
is scalar @$schemas, 1, 'got one schema from "available_database_schemas"';
isa_ok $schemas->[0], 'Bio::Track::Schema', 'first schema';

# a quick check to make sure that the database connection works...
my $rs;
lives_ok { $rs = $schema->get_lanes_by_id('5477_6', 'lane') }
  'can call "get_lanes_by_id" on schema successfully';

is $rs->count, 40, 'got expected number of rows in ResultSet';
isa_ok $rs->first, 'Bio::Track::Schema::Result::LatestLane', 'lane';

#---------------------------------------

# production config - this will only work when running on a machine within Sanger

# before trying to do anything in a production context, we'll try to connect to the
# MySQL database that's specified in the config. If we can't connect to it, there's
# no point trying the rest of these tests.

$d = Bio::Path::Find::Database->new(environment => 'prod', config_file => 't/data/05_find_database/prod.conf');

my $can_connect;
try {
  $can_connect = 1 if $schema = $d->get_schema('pathogen_prok_track');
} catch {
  $can_connect = 0;
};

SKIP: {
  skip "can't connect to MySQL database", 4 unless $can_connect;

  my $expected_sources = [ qw(
    information_schema
    pathogen_ST131_external
    pathogen_annotation_track
    pathogen_cgps_track
    pathogen_dog_track
    pathogen_efaecalis_external
    pathogen_euk_external
    pathogen_euk_track
    pathogen_fsu_file_exists
    pathogen_helminth_external
    pathogen_helminth_track
    pathogen_kpn_trans_external
    pathogen_ldonovani_external
    pathogen_lpneumo_external
    pathogen_orthomcl
    pathogen_pacbio_track
    pathogen_prok_external
    pathogen_prok_track
    pathogen_prok_vrpipe
    pathogen_qc_grind
    pathogen_reference_track
    pathogen_rnaseq_test
    pathogen_rnd_track
    pathogen_sb18_mapping
    pathogen_svenez_external
    pathogen_usfl_external
    pathogen_virus_external
    pathogen_virus_track
  )];

# these are the databases that have a directory within the test suite. We
# shouldn't get "pathogen_virus_track" because, although it's found in the list
# of data sources, there's no accompanying directory
  $expected_dbs = [ qw(
    pathogen_helminth_external
    pathogen_helminth_track
    pathogen_prok_track
  ) ];

  is_deeply $d->data_sources, $expected_sources, 'got expected list of data sources in production mode';
  is_deeply $d->available_database_names, $expected_dbs, 'got expected list of names of available databases in production mode';
  is $schema->get_lanes_by_id('5477_6', 'lane'), 11, 'got expected number of lanes from production DB';
  is scalar @{ $d->available_database_schemas}, 3, 'got expected number of schemas';
}

$DB::single = 1;

done_testing;

