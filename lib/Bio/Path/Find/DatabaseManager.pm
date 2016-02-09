
package Bio::Path::Find::DatabaseManager;

# ABSTRACT: class to handle interactions with the pathogens tracking databases

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw( carp );
use DBI;
use Path::Class;

use Types::Standard qw(
  Str
  ArrayRef
  HashRef
);

use Bio::Path::Find::Types qw(
  BioPathFindDatabase
);

use Bio::Path::Find::Database;
use Bio::Path::Find::Exception;

with 'Bio::Path::Find::Role::HasConfig',
     'MooseX::Log::Log4perl';

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

=attr schema_name

=cut

has 'schema_name' => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

#---------------------------------------

=attr connection_params

A reference to a hash containing database connection parameters from the
configuration.

The parameters should be given using the key C<connection_params> and must
specify C<driver>, which should be either "mysql" or "SQLite".

If the driver is "mysql", the connection parameters must also include
C<host>, C<port>, and C<user>. If a password is required it should be
given using C<pass>.

  <connection_params>
    <tracking>
      driver mysql
      host   mysql_database_host
      port   3306
      user   myuser
      pass   mypass
    </tracking>
  </connection_params>

If the driver is "SQLite", the configuration must include C<dbname>, which
gives the path to the SQLite database file:

  <connection_params>
    <tracking>
      driver SQLite
      dbname /path/to/database.db
    </tracking>
  </connection_params>

=cut

has 'connection_params' => (
  is      => 'ro',
  isa     => HashRef,
  lazy    => 1,
  builder => '_build_connection_params',
);

sub _build_connection_params {
  my $self = shift;

  my $cp = $self->config->{connection_params};

  Bio::Path::Find::Exception->throw(
    msg => "ERROR: configuration does not specify any database connection parameters ('connection_params')" )
    unless ( defined $cp and ref $cp eq 'HASH' );

  my $params = $cp->{$self->schema_name};

  Bio::Path::Find::Exception->throw(
    msg => 'ERROR: configuration does not specify connection parameters for schema name ("'
           . $self->schema_name . '")' )
    unless defined $params;

  Bio::Path::Find::Exception->throw(
    msg => 'ERROR: configuration does not specify the database driver ("driver")' )
    unless exists $params->{driver};

  if ( $params->{driver} eq 'mysql' ) {
    foreach my $param ( qw( host port user ) ) {
      Bio::Path::Find::Exception->throw(
        msg => "ERROR: configuration does not specify a required database connection parameter, $param" )
        unless $params->{$param};
    }
  }
  elsif ( $params->{driver} eq 'SQLite' ) {
    Bio::Path::Find::Exception->throw(
      msg => 'ERROR: configuration does not specify a required database connection parameter, dbname' )
      unless $params->{dbname};
  }
  else {
    Bio::Path::Find::Exception->throw(
      msg => "ERROR: configuration does not specify a valid database driver; must be either 'mysql' or 'SQLite'" )
  }

  return $params;
}

#---------------------------------------

=attr data_sources

A reference to an array containing the names of the available data sources.

The list is generated using the L<DBI::data_sources> class method. If the
configuration specifies the MySQL database driver, the list will contain the
names of available databases in the specified MySQL instance. If the config
specifies the SQLite driver, the list will contain the name of the database
file itself.

=cut

has 'data_sources' => (
  is      => 'ro',
  isa     => ArrayRef[Str],
  lazy    => 1,
  builder => '_build_data_sources',
);

sub _build_data_sources {
  my $self = shift;

  my $c = $self->connection_params;

  # ask the DBI for a list of sources
  my @sources = grep s/^dbi:.*?://i, DBI->data_sources($c->{driver}, $c);

  # if we're using SQLite, "data_sources" won't return anything, so add
  # the name of the database itself

  my $dbname = file($c->{dbname})->basename;
  $dbname =~ s/\..*$//;

  push @sources, $dbname if $c->{dbname};

  Bio::Path::Find::Exception->throw( msg => 'ERROR: failed to retrieve a list of data sources' )
    unless scalar @sources;

  if ( $self->log->is_debug ) {
    require Data::Dump;
    $self->log->debug("list of data sources from database:\n", Data::Dump::dd( \@sources ) );
  }

  return \@sources;
}

#---------------------------------------

=attr databases

A reference to a hash containing available L<Bio::Path::Find::Database>
objects, keyed on the name of the database.

In order to appear in this list a database must:

=over

=item exist in the list of data sources (see L<data_sources>)

=item have an associated directory structure (see
L<Bio::Path::Find::Database::hierarchy_root_dir>).

=back

=cut

has 'databases' => (
  traits  => ['Hash'],
  is      => 'ro',
  isa     => HashRef[BioPathFindDatabase],
  lazy    => 1,
  handles => {
    add_database   => 'set',
    get_database   => 'get',
    all_databases  => 'values',
    database_names => 'keys',
    database_pairs => 'kv',
    num_databases  => 'count',
  },
  builder => '_build_database_objects',
);

sub _build_database_objects {
  my $self = shift;

  my %databases;
  foreach my $database_name ( @{ $self->data_sources } ) {
    # it's cheap to build all of these objects, because they won't attempt to
    # make a database connection until it's needed ("schema" is a lazy
    # attribute)
    my $database = Bio::Path::Find::Database->new(
      name        => $database_name,
      schema_name => $self->schema_name,
    );

    next if ( not $self->connection_params->{no_db_root} and
              not defined $database->hierarchy_root_dir );

    # next unless defined $database->hierarchy_root_dir;

    $databases{$database_name} = $database;
  }

  return \%databases;
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 add_database($name, $database)

Adds a L<Bio::Path::Find::Database> to the list of databases that are tracked
by the database manager.

=head2 get_database($name)

Returns the L<Bio::Path::Find::Database> with the given name.

=head2 all_databases

Returns an array of the L<Bio::Path::Find::Database> objects that are
available from this database manager.

=head2 database_names

Returns a list of the names of all of the L<Bio::Path::Find::Database>
objects that are available from this database manager.

=head2 database_pairs

Returns key/value pairs giving the name and object for each database:

 foreach my $pair ( $dbm->database_pairs ) {
   my $db_name = $pair->[0];
   my $database = $pair->[1];
   ...
 }

=cut

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

