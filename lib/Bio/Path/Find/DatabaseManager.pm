
package Bio::Path::Find::DatabaseManager;

# ABSTRACT: class to handle interactions with the pathogens tracking databases

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Types::Standard qw( Str ArrayRef HashRef );
use Carp qw( croak carp );
use DBI;

use Bio::Path::Find::Types qw( BioPathFindDatabase );
use Bio::Track::Schema;
use Bio::Path::Find::Database;

with 'Bio::Path::Find::Role::HasEnvironment',
     'Bio::Path::Find::Role::HasConfig';

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

=attr connection_params

A reference to a hash containing database connection parameters from the
config.

The parameters should be given using the key C<connection_params> and must
specify C<host>, C<port>, and C<user>. If a password is required it should be
given using C<pass>. For example, in a L<Config::General>-style config file:

  <connection_params>
    host mysql_database_host
    port 3306
    user myuser
    pass mypass
  </connection_params>

=cut

has 'connection_params' => (
  is      => 'ro',
  isa     => HashRef[Str],
  lazy    => 1,
  builder => '_build_connection_params',
);

sub _build_connection_params {
  my $self = shift;

  my $connection = $self->config->{connection_params};

  croak 'ERROR: configuration does not specify any database connection parameters ("connection_params")'
    unless ( defined $connection and ref $connection eq 'HASH' );

  foreach ( qw( host user port ) ) {
    croak "ERROR: configuration does not specify one of the required database connection parameters ($_)"
      unless exists $connection->{$_};
  }

  return $connection;
}

#---------------------------------------

=attr production_db_names

A reference to an array listing the names of the production databases. The names
should be specified in the configuration using the key C<production_db>. For
example, in a L<Config::General>-style config:

  production_db pathogen_euk_track
  production_db pathogen_prok_track
  ...

Note that the order of the databases is significant: the list of B<available>
databases will be sorted so that names are returned in the order specified in
the C<production_db> list.

If C<production_db> is not found in the config, a warning is issued and we use
the following default list:

  pathogen_pacbio_track
  pathogen_prok_track
  pathogen_euk_track
  pathogen_virus_track
  pathogen_helminth_track

B<Read-only>.

=cut

has 'production_db_names' => (
  is      => 'ro',
  isa     => ArrayRef[Str],
  lazy    => 1,
  builder => '_build_production_db_names',
);

sub _build_production_db_names {
  my $self = shift;

  my $dbs = $self->config->{production_db};

  if ( not defined $dbs ) {
    carp 'WARNING: configuration does not specify the list of production databases ("production_db"); using default list';
    $dbs = [ qw(
      pathogen_pacbio_track
      pathogen_prok_track
      pathogen_euk_track
      pathogen_virus_track
      pathogen_helminth_track
    ) ];
  }

  croak 'ERROR: no valid list of production databases ("production_db")'
    unless ( ref $dbs eq 'ARRAY' and scalar @$dbs );

  return $dbs;
}

#---------------------------------------

=attr data_sources

A reference to an array containing the names of the available data sources.

In a production environment, the data sources will be the names of the
databases that are found in the MySQL instance that is specified in the
config.

In a test environment, there is a single data source, which is hard-coded.

=cut

has 'data_sources' => (
  is      => 'ro',
  isa     => ArrayRef[Str],
  lazy    => 1,
  builder => '_build_data_sources',
);

sub _build_data_sources {
  my $self = shift;

  # if we're in the test environment, spoof the data sources list and provide
  # the name of a test DB. Otherwise, retrieve the list by connecting to the
  # MySQL database using the connection parameters from the config
  my @sources = $self->environment eq 'test'
              ? ( 'pathogen_track_test' )
              : grep s/^DBI:mysql://, DBI->data_sources('mysql', $self->connection_params);

  croak 'ERROR: failed to retrieve a list of data sources'
    unless scalar @sources;

  return \@sources;
}

#---------------------------------------

=attr database_order

A reference to an array containing an ordered list of database names.

This will be the list of ALL databases (both available and unavailable) in the
MySQL instance, ordered with "track" DBs first, then "external", and then
re-ordered according to the database names given in the C<production_db> slot
in the config.

=cut

has 'database_order' => (
  is      => 'rw',
  isa     => ArrayRef[Str],
  lazy    => 1,
  builder => '_build_database_order',
);

sub _build_database_order {
  my $self = shift;

  my @reordered_db_list;

  my %db_list_lookup = map { $_ => 1 } @{ $self->_database_names };

  # first, add production databases to the output list
  foreach my $database_name ( @{ $self->production_db_names } ) {
    next unless $db_list_lookup{$database_name};
    push @reordered_db_list, $database_name;

    # remove already added DBs from the lookup, so that we can add the
    # remainder below
    delete $db_list_lookup{$database_name};
  }

  # add remaining DBs to output
  foreach my $database_name ( sort keys %db_list_lookup ) {
    push @reordered_db_list, $database_name;
  }

  return \@reordered_db_list;
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
  },
  builder => '_build_database_objects',
);

sub _build_database_objects {
  my $self = shift;

  my %databases;
  foreach my $database_name ( @{ $self->_database_names } ) {
    # it's cheap to build all of these objects, because they won't attempt to
    # make a database connection until it's needed ("schema" is a lazy
    # attribute)
    my $database = Bio::Path::Find::Database->new(
      name        => $database_name,
      environment => $self->environment,
      config      => $self->config
    );

    next unless defined $database->hierarchy_root_dir;

    $databases{$database_name} = $database;
  }

  return \%databases;
}

#-------------------------------------------------------------------------------
#- private attributes ---------------------------------------------------------
#-------------------------------------------------------------------------------

# this is the UNORDERED list of database names. In production mode the names
# are retrieved from the data sources. In test most the list is hard-coded.

has '_database_names' => (
  is      => 'ro',
  isa     => ArrayRef [Str],
  lazy    => 1,
  builder => '_build_database_names',
);

sub _build_database_names {
  my $self = shift;

  my @database_names = ();
  if ( $self->is_test_env ) {
    push @database_names, 'pathogen_track_test';
  }
  else {
    push @database_names, grep /^pathogen_.+_track$/,    @{ $self->data_sources };
    push @database_names, grep /^pathogen_.+_external$/, @{ $self->data_sources };
  }

  return \@database_names;
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

