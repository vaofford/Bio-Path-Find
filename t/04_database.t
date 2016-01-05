
use strict;
use warnings;

use Test::More tests => 20;
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

# reading config from file

# check we can get a DSN for a mysql database
my $db;
lives_ok {
    $db = Bio::Path::Find::Database->new(
      name        => 'pathogen_prok_track',
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
      config_file => file( qw( t data 04_database sqlite.conf ) ),
    )
  }
  'got a B::P::F::Database object for a SQLite connection using config file';

is $db->_get_dsn, 'dbi:SQLite:dbname=' . file( qw( t data pathogen_prok_track.db ) ),
  'got expected SQLite DSN using config file';
isa_ok $db->schema, 'Bio::Track::Schema', 'schema';

#---------------------------------------

# check we can use a config hash too
my $config = {
  db_root            => file( qw( t data linked ) ),
  hierarchy_template => 'genus:species:TRACKING:sample:lane',
  connection_params  => {
    driver => 'mysql',
    host   => 'my_db_host',
    port   => 3306,
    user   => 'username',
    pass   => 'password',
  },
  db_subdirs => {
    pathogen_prok_track => 'prokaryotes',
  },
};

lives_ok {
    $db = Bio::Path::Find::Database->new(
      name   => 'pathogen_prok_track',
      config => $config,
    )
  }
  'got a B::P::F::Database object using config hash';

is $db->_get_dsn, 'DBI:mysql:host=my_db_host;port=3306;database=pathogen_prok_track',
  'got expected DSN using config hash';

#-------------------------------------------------------------------------------

# look for warnings and exceptions

# missing db_root
$config = {
  # no db_root
  hierarchy_template => 'genus:species:TRACKING:sample:lane',
  connection_params  => {
    driver => 'SQLite',
    dbname => file( qw( t data pathogen_prok_track.db ) ),
  },
  db_subdirs => {
    pathogen_prok_track => 'prokaryotes',
  },
};

$db = Bio::Path::Find::Database->new( name => 'pathogen_prok_track', config => $config );

throws_ok { $db->db_root }
  qr/data hierarchy root directory is not defined/,
  'exception with missing db_root';

#---------------------------------------

# check for a valid template from previous config
is $db->hierarchy_template, $config->{hierarchy_template},
  'found valid template in config';

# missing template
$config = {
  db_root            => file( qw( t data linked ) ),
  # no template
  connection_params  => {
    driver => 'SQLite',
    dbname => file( qw( t data pathogen_prok_track.db ) ),
  },
  db_subdirs => {
    pathogen_prok_track => 'prokaryotes',
  },
};

$db = Bio::Path::Find::Database->new( name => 'pathogen_prok_track', config => $config );

my $template = $db->hierarchy_template;
is $template, 'genus:species-subspecies:TRACKING:projectssid:sample:technology:library:lane',
  'got default template';

# invalid template
$config->{hierarchy_template} = '*notavalidtemplate*';
$db = Bio::Path::Find::Database->new( name => 'pathogen_prok_track', config => $config );

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

$db = Bio::Path::Find::Database->new( name => 'pathogen_prok_track', config => $config );

throws_ok { $db->_get_dsn }
  qr/must specify database connection parameters/,
  'exception when connection params missing from config';

#---------------------------------------

# missing DB driver
$config = {
  db_root            => file( qw( t data linked ) ),
  hierarchy_template => 'genus:species:TRACKING:sample:lane',
  connection_params  => {
    # missing driver
    host     => 'test_db_host',
    port     => 3308,
    user     => 'username',
    pass     => 'password',
  },
  db_subdirs => {
    pathogen_prok_track => 'prokaryotes',
  },
};

$db = Bio::Path::Find::Database->new( name => 'pathogen_prok_track', config => $config );

throws_ok { $db->_get_dsn }
  qr/must specify a database driver/,
  'exception when driver is missing from config';

#---------------------------------------

# bad driver
$config->{connection_params}->{driver} = 'not-a-real-driver';
$db = Bio::Path::Find::Database->new( name => 'pathogen_prok_track', config => $config );

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

$db = Bio::Path::Find::Database->new( name => 'pathogen_prok_track', config => $config );

my $root;
warning_like { $root = $db->hierarchy_root_dir }
  qr/does not specify the mapping/,
  'got warning about missing mapping in config';

is $root, file( qw( t data linked prokaryotes seq-pipelines ) ),
  'got correct root dir without subdir';

#-------------------------------------------------------------------------------

# see if we can perform tests on a test DB on a MySQL server

SKIP: {
  skip 'no credentials for live DB; set TEST_MYSQL_HOST, TEST_MYSQL_PORT, TEST_MYSQL_USER', 1
    unless ( $ENV{TEST_MYSQL_HOST} and
             $ENV{TEST_MYSQL_PORT} and
             $ENV{TEST_MYSQL_USER} );

  $config = {
    db_root            => file( qw( t data linked ) ),
    hierarchy_template => 'genus:species:TRACKING:sample:lane',
    connection_params  => {
      driver => 'mysql',
      host   => $ENV{TEST_MYSQL_HOST},
      port   => $ENV{TEST_MYSQL_PORT},
      user   => $ENV{TEST_MYSQL_USER},
    },
    db_subdirs => {
      pathogen_prok_track => 'prokaryotes',
    },
  };

  $db = Bio::Path::Find::Database->new(
    name   => 'pathogen_track_test',
    config => $config,
  );

  isa_ok $db->schema, 'Bio::Track::Schema', 'schema';

  lives_ok { $db->schema->resultset('LatestLane')->count }
    'can count rows in lane table';
}

done_testing;

