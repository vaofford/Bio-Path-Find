
package Test::SchemaOne;

use Moose;
extends 'DBIx::Class::Schema';

#-------------------------------------------------------------------------------

package Test::SchemaTwo;

use Moose;
extends 'DBIx::Class::Schema';

#-------------------------------------------------------------------------------

package main;

use strict;
use warnings;

use Test::More tests => 29;
use Test::Exception;
use Test::Warn;
use Try::Tiny;
use Path::Class;

use lib 't';

use Test::Setup;

unless ( -d dir( qw( t data linked ) ) ) {
  diag 'creating symlink directory';
  Test::Setup::make_symlinks;
}

use_ok('Bio::Path::Find::Database');

#-------------------------------------------------------------------------------

# first check we can use a valid config hash
my $config = {
  db_root            => file( qw( t data linked ) ),
  connection_params  => {
    tracking => {
      driver => 'mysql',
      host   => 'my_db_host',
      port   => 3306,
      user   => 'username',
      pass   => 'password',
      # no schema_class
    },
  },
};

my $db;
lives_ok {
    $db = Bio::Path::Find::Database->new(
      name        => 'pathogen_prok_track',
      schema_name => 'tracking',
      config      => $config,
    )
  }
  'got a B::P::F::Database object using config hash';

is $db->_get_dsn, 'DBI:mysql:host=my_db_host;port=3306;database=pathogen_prok_track',
  'got expected DSN using config hash';

#---------------------------------------

# check that we get an exception when we try to get a Schema object, because
# schema_class isn't defined

throws_ok { $db->schema }
  qr/"schema_class" not defined/,
  'exception when schema_class not defined in config';

#---------------------------------------

# check that we get an exception when we specify a dodgy schema class name in
# the config
$config->{connection_params}->{tracking}->{schema_class} = "x; print qq(hello\n)";

throws_ok { $db->schema }
  qr/doesn't look like a valid schema class name/,
  'exception when schema_class is invalid';

#---------------------------------------

# check we get an exception if "driver" isn't defined

$config->{connection_params}->{tracking}->{schema_class} = 'non-existent-schema-class';
delete $config->{connection_params}->{tracking}->{driver};

$db = Bio::Path::Find::Database->new(
  name        => 'pathogen_prok_track',
  schema_name => 'tracking',
  config      => $config,
);

throws_ok { $db->schema }
  qr/"driver" not defined/,
  'exception when driver not defined in config';

#---------------------------------------

# check that we get an exception when we specify a schema class that doesn't
# exist

$config->{connection_params}->{tracking}->{driver} = 'SQLite';

$db = Bio::Path::Find::Database->new(
  name        => 'pathogen_prok_track',
  schema_name => 'tracking',
  config      => $config,
);

throws_ok { $db->schema }
  qr/could not load schema class/,
  'exception when specifying a non-existent schema class';

#-------------------------------------------------------------------------------

# multiple schemas in one config

$config = {
  db_root           => file(qw( t data linked )),
  connection_params => {
    tracking => {
      driver       => 'mysql',
      host         => 'my_db_host',
      port         => 3306,
      user         => 'username',
      pass         => 'password',
      schema_class => 'Test::SchemaOne',
    },
    seqw => {
      driver       => 'SQLite',
      dbname       => 't/data/04_database/seqw.db',
      no_db_root   => 1,
      schema_class => 'Test::SchemaTwo',
    },
  },
};

my $tracking_db = Bio::Path::Find::Database->new(
  name        => 'pathogen_prok_track',
  schema_name => 'tracking',
  config      => $config,
);

my $seqw_db = Bio::Path::Find::Database->new(
  name        => 'sequencescape_warehouse',
  schema_name => 'seqw',
  config      => $config,
);

my ( $tracking_schema, $seqw_schema );
lives_ok { $tracking_schema = $tracking_db->schema } 'got one schema';
lives_ok { $seqw_schema     = $seqw_db->schema     } 'got second schema';

isa_ok $tracking_schema, 'Test::SchemaOne';
isa_ok $seqw_schema,     'Test::SchemaTwo';

# make sure that we don't get an exception when we don't specify a root directory
# for a database, but also set no_db_root true
is undef, $seqw_db->db_root, 'no db_root, but no exception, when no_db_root true';

#-------------------------------------------------------------------------------

# reading config from file

# check we can get a DSN for a mysql database
lives_ok {
    $db = Bio::Path::Find::Database->new(
      name        => 'pathogen_prok_track',
      schema_name => 'tracking',
      config_file => file( qw( t data 04_database mysql.conf ) ),
    )
  }
  'got a B::P::F::Database object for a MySQL connection using config file';

is $db->db_root, dir( qw( t data linked ) ), 'got expected root directory';
is $db->_get_dsn, 'DBI:mysql:host=test_db_host;port=3306;database=pathogen_prok_track',
  'got expected MySQL DSN using config file';
isa_ok $db->schema, 'Bio::Track::Schema', 'schema';

#---------------------------------------

# and for an SQLite DB
lives_ok {
    $db = Bio::Path::Find::Database->new(
      name        => 'pathogen_prok_track',
      schema_name => 'tracking',
      config_file => file( qw( t data 04_database sqlite.conf ) ),
    )
  }
  'got a B::P::F::Database object for a SQLite connection using config file';

is $db->_get_dsn, 'dbi:SQLite:dbname=' . file( qw( t data pathogen_prok_track.db ) ),
  'got expected SQLite DSN using config file';
isa_ok $db->schema, 'Bio::Track::Schema', 'schema';

#-------------------------------------------------------------------------------

# look for warnings and exceptions

# missing db_root
$config = {
  # no db_root
  hierarchy_template => 'genus:species:TRACKING:sample:lane',
  connection_params  => {
    tracking => {
      driver       => 'SQLite',
      schema_class => 'Bio::Track::Schema',
      dbname       => file(qw( t data pathogen_prok_track.db )),
    },
  },
  db_subdirs => {
    pathogen_prok_track => 'prokaryotes',
  },
};

$db = Bio::Path::Find::Database->new(
  name        => 'pathogen_prok_track',
  schema_name => 'tracking',
  config      => $config
);

throws_ok { $db->db_root }
  qr/data hierarchy root directory is not defined/,
  'exception with missing db_root';

#---------------------------------------

# check for a valid template
is $db->hierarchy_template, $config->{hierarchy_template},
  'found valid template in config';

# missing template
$config = {
  db_root => file(qw( t data linked )),
  # no template
  connection_params => {
    tracking => {
      driver      => 'SQLite',
      dbname      => file(qw( t data pathogen_prok_track.db )),
      schema_name => 'Bio::Track::Schema',
    },
  },
  db_subdirs => {
    pathogen_prok_track => 'prokaryotes',
  },
};

$db = Bio::Path::Find::Database->new(
  name        => 'pathogen_prok_track',
  schema_name => 'tracking',
  config      => $config
);

my $template = $db->hierarchy_template;
is $template, 'genus:species-subspecies:TRACKING:projectssid:sample:technology:library:lane',
  'got default template';

# invalid template
$config->{hierarchy_template} = '*notavalidtemplate*';
$db = Bio::Path::Find::Database->new(
  name        => 'pathogen_prok_track',
  schema_name => 'tracking',
  config      => $config
);

throws_ok { $db->hierarchy_template }
  qr/invalid directory hierarchy template/,
  'exception with invalid template';

#---------------------------------------

# missing connection params
$config = {
  db_root            => file( qw( t data linked ) ),
  hierarchy_template => 'genus:species:TRACKING:sample:lane',
  # no connection params
  db_subdirs => {
    pathogen_prok_track => 'prokaryotes',
  },
};

$db = Bio::Path::Find::Database->new(
  name        => 'pathogen_prok_track',
  schema_name => 'tracking',
  config      => $config
);

throws_ok { $db->_get_dsn }
  qr/must specify database connection parameters/,
  'exception when connection params missing from config';

#---------------------------------------

# missing DB driver
$config = {
  db_root            => file( qw( t data linked ) ),
  hierarchy_template => 'genus:species:TRACKING:sample:lane',
  connection_params  => {
    tracking => {
      # missing driver
      host     => 'test_db_host',
      port     => 3308,
      user     => 'username',
      pass     => 'password',
    },
  },
  db_subdirs => {
    pathogen_prok_track => 'prokaryotes',
  },
};

$db = Bio::Path::Find::Database->new(
  name        => 'pathogen_prok_track',
  schema_name => 'tracking',
  config      => $config
);

throws_ok { $db->_get_dsn }
  qr/must specify a database driver/,
  'exception when driver is missing from config';

#---------------------------------------

# bad driver
$config->{connection_params}->{tracking}->{driver} = 'not-a-real-driver';
$db = Bio::Path::Find::Database->new(
  name        => 'pathogen_prok_track',
  schema_name => 'tracking',
  config      => $config
);

throws_ok { $db->_get_dsn }
  qr/not a valid database driver/,
  'exception with unknown driver';

#---------------------------------------

# missing mapping
$config = {
  db_root            => file( qw( t data linked ) ),
  hierarchy_template => 'genus:species:TRACKING:sample:lane',
  connection_params  => {
    driver => 'SQLite',
    dbname => file( qw( t data pathogen_prok_track.db ) ),
  },
  # no mapping
};

$db = Bio::Path::Find::Database->new(
  name        => 'pathogen_prok_track',
  schema_name => 'tracking',
  config      => $config
);

is $db->hierarchy_root_dir, file( qw( t data linked prokaryotes seq-pipelines ) ),
  'got correct root dir without subdir';

#-------------------------------------------------------------------------------

# see if we can perform tests on a test DB on a MySQL server

SKIP: {
  skip 'no credentials for live DB; set TEST_MYSQL_HOST, TEST_MYSQL_PORT, TEST_MYSQL_USER', 2
    unless ( $ENV{TEST_MYSQL_HOST} and
             $ENV{TEST_MYSQL_PORT} and
             $ENV{TEST_MYSQL_USER} );

  $config = {
    db_root            => file(qw( t data linked )),
    hierarchy_template => 'genus:species:TRACKING:sample:lane',
    connection_params  => {
      tracking => {
        driver       => 'mysql',
        host         => $ENV{TEST_MYSQL_HOST},
        port         => $ENV{TEST_MYSQL_PORT},
        user         => $ENV{TEST_MYSQL_USER},
        schema_class => 'Bio::Track::Schema',
      },
    },
    db_subdirs => {
      pathogen_prok_track => 'prokaryotes',
    },
  };

  $db = Bio::Path::Find::Database->new(
    name        => 'pathogen_track_test',
    schema_name => 'tracking',
    config      => $config,
  );

  isa_ok $db->schema, 'Bio::Track::Schema', 'schema';

  lives_ok { $db->schema->resultset('LatestLane')->count }
    'can count rows in lane table';
}

# done_testing;

