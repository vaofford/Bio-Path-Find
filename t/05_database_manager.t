
use strict;
use warnings;

use Test::More tests => 17;
use Test::Exception;
use Test::Warn;
use Try::Tiny;
use Path::Class;
use Log::Log4perl qw( :easy );

# initialise l4p to avoid warnings
Log::Log4perl->easy_init( $FATAL );

# set up the "linked" directory for the test suite
use lib 't';

use Test::Setup;

unless ( -d dir( qw( t data linked ) ) ) {
  diag 'creating symlink directory';
  Test::Setup::make_symlinks;
}
use_ok('Bio::Path::Find::DatabaseManager');

#-------------------------------------------------------------------------------

# read config from file

my $dbm;
lives_ok {
    $dbm = Bio::Path::Find::DatabaseManager->new(
      config_file => file( qw( t data 05_database_manager test.conf ) )->stringify,
      schema_name => 'tracking',
    )
  }
  'no exception instantiating with valid config';

#---------------------------------------

# use a config hash

my $config = {
  db_root => file(qw( t data 05_database_manager root_dir ))->stringify,
  hierarchy_template =>
    'genus:species-subspecies:TRACKING:projectssid:sample:technology:library:lane',
  connection_params => {
    tracking => {
      driver       => 'SQLite',
      dbname       => file(qw( t data empty_tracking_database.db ))->stringify,
      schema_class => 'Bio::Track::Schema',
    },
  },
  db_subdirs => {
    pathogen_virus_track => 'viruses',
    pathogen_prok_track  => 'prokaryotes',
  },
};

lives_ok { $dbm = Bio::Path::Find::DatabaseManager->new( config => $config, schema_name => 'tracking' ) }
  'no exception instantiating with valid config';

#---------------------------------------

# check exceptions with invalid configuration

# no params for specified schema name
throws_ok {
    Bio::Path::Find::DatabaseManager->new( config => $config, schema_name => 'non-existent' )->connection_params
  }
  qr/does not specify connection parameters for schema name/,
  'exception with missing connection params for named schema';

# missing params entirely
delete $config->{connection_params};

throws_ok {
    Bio::Path::Find::DatabaseManager->new( config => $config, schema_name => 'tracking' )->connection_params
  }
  qr/does not specify any database connection parameters/,
  'exception with missing connection params';

# missing driver
$config->{connection_params}->{tracking} = {
  # no driver
  dbname       => file( qw( t data empty_tracking_database.db ) )->stringify,
  schema_class => 'Bio::Track::Schema',
};

throws_ok {
    Bio::Path::Find::DatabaseManager->new( config => $config, schema_name => 'tracking' )->connection_params
  }
  qr/does not specify the database driver/,
  'exception with missing driver';

# missing driver
$config->{connection_params}->{tracking}->{driver} = 'not-a-supported-driver';

throws_ok {
    Bio::Path::Find::DatabaseManager->new( config => $config, schema_name => 'tracking' )->connection_params
  }
  qr/does not specify a valid database driver/,
  'exception with unsupported driver';

# missing mysql param
$config->{connection_params}->{tracking} = {
  driver       => 'mysql',
  # host       => 'db_host',
  port         => 3306,
  user         => 'db_user',
  schema_class => 'Bio::Track::Schema',
};

throws_ok {
    Bio::Path::Find::DatabaseManager->new( config => $config, schema_name => 'tracking' )->connection_params
  }
  qr/does not specify a required database connection parameter, host/,
  'exception with missing mysql param';

# missing SQLite param
$config->{connection_params}->{tracking} = {
  driver       => 'SQLite',
  # dbname     => 'database.db',
  schema_class => 'Bio::Track::Schema',
};

throws_ok {
    Bio::Path::Find::DatabaseManager->new( config => $config, schema_name => 'tracking' )->connection_params
  }
  qr/does not specify a required database connection parameter, dbname/,
  'exception with missing SQLite param';

#-------------------------------------------------------------------------------

# check data sources

# local SQLite DB

$config = {
  db_root => file( qw( t data 05_database_manager root_dir ) )->stringify,
  hierarchy_template => 'genus:species-subspecies:TRACKING:projectssid:sample:technology:library:lane',
  connection_params => {
    tracking => {
      driver       => 'SQLite',
      dbname       => file( qw( t data empty_tracking_database.db ) )->stringify,
      schema_class => 'Bio::Track::Schema',
    },
  },
  db_subdirs => {
    pathogen_virus_track => 'viruses',
    pathogen_prok_track  => 'prokaryotes',
  },
};

lives_ok { $dbm = Bio::Path::Find::DatabaseManager->new( config => $config, schema_name => 'tracking' ) }
  'no exception with valid SQLite config';

is_deeply $dbm->data_sources, [ 'empty_tracking_database' ],
  'got SQLite DB name in data sources';

my $db;
lives_ok { $db = $dbm->get_database('empty_tracking_database') }
  'no exception getting Bio::Path::Find::Database for SQLite DB';

isa_ok $db, 'Bio::Path::Find::Database', 'database object';

#---------------------------------------

# MySQL DB

SKIP: {
  skip 'no access to live DB; set TEST_MYSQL_HOST, TEST_MYSQL_PORT, TEST_MYSQL_USER', 4
    unless ( $ENV{TEST_MYSQL_HOST} and
             $ENV{TEST_MYSQL_PORT} and
             $ENV{TEST_MYSQL_USER} );

  $config = {
    db_root => file( qw( t data 05_database_manager root_dir ) )->stringify,
    hierarchy_template => 'genus:species-subspecies:TRACKING:projectssid:sample:technology:library:lane',
    connection_params => {
      tracking => {
        driver       => 'mysql',
        host         => $ENV{TEST_MYSQL_HOST},
        port         => $ENV{TEST_MYSQL_PORT},
        user         => $ENV{TEST_MYSQL_USER},
        schema_class => 'Bio::Track::Schema',
      },
    },
    db_subdirs => {
      pathogen_virus_track => 'viruses',
      pathogen_prok_track  => 'prokaryotes',
    },
  };

  lives_ok { $dbm = Bio::Path::Find::DatabaseManager->new( config => $config, schema_name => 'tracking' ) }
    'no exception with valid live mysql config';

  my $can_connect;
  try {
    $can_connect = 1 if $dbm->data_sources;
  } catch {
    $can_connect = 0;
  };

  SKIP: {
    skip "MySQL database tests; check connection params", 3 unless $can_connect;

    my $ds;
    lives_ok { $ds = $dbm->data_sources }
      'no exception building list of production data_sources';

    my $db = $dbm->get_database('pathogen_test_external');
    isa_ok $db, 'Bio::Path::Find::Database', 'database object';
    isa_ok $db->schema, 'Bio::Track::Schema', 'schema';
  }

}

#-------------------------------------------------------------------------------

# done_testing;

