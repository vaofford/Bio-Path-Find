
package Bio::Path::Find::Database;

# ABSTRACT: class to handle interactions with the pathogens tracking databases

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Types::Standard qw( Str ArrayRef HashRef );
use Carp qw( croak carp );
use DBI;

use Bio::Track::Schema;
use Bio::Path::Find::Path;
use Bio::Path::Find::Types qw( BioPathFindPath BioTrackSchema );

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

The parameters should be given using the key C<connection_params> and must specify
C<host>, C<port>, and C<user>. If a password is required it should be given
using C<pass>. For example, in a L<Config::General>-style config file:

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
  writer  => '_set_connection_params',
  builder => '_build_connection_params',
);

sub _build_connection_params {
  my $self = shift;

  my $connection = $self->_config->{connection_params};

  croak 'ERROR: configuration (' . $self->config_file
       . ') does not specify any database connection parameters ("connection_params")'
    unless ( defined $connection and ref $connection eq 'HASH' );

  foreach ( qw( host user port ) ) {
    croak 'ERROR: configuration (' . $self->config_file
         . ") does not specify one of the required database connection parameters ($_)"
      unless exists $connection->{$_};
  }

  return $connection;
}

#---------------------------------------

=attr production_dbs

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

has 'production_dbs' => (
  is      => 'ro',
  isa     => ArrayRef[Str],
  lazy    => 1,
  writer  => '_set_production_dbs',
  builder => '_build_production_dbs',
);

sub _build_production_dbs {
  my $self = shift;

  my $dbs = $self->_config->{production_db};

  if ( not defined $dbs ) {
    carp 'WARNING: configuration (' . $self->config_file
         . ') does not specify the list of production databases ("production_db"); using default list';
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
databases that are found in the MySQL instance which is specified in the
config.

In a test environment, the data source is a test SQLite database which is part
of the test suite.

=cut

has 'data_sources' => (
  is      => 'ro',
  isa     => ArrayRef[Str],
  lazy    => 1,
  writer  => '_set_data_sources',
  builder => '_build_data_sources',
);

sub _build_data_sources {
  my $self = shift;

  # if we're in the test environment, spoof the data sources list and provide
  # the name of a test DB. Otherwise, retrieve the list by connecting to the
  # MySQL database using the connection parameters from the config
  my @sources = $self->environment eq 'test'
              ? ( 'pathogen_test_track' )
              : grep s/^DBI:mysql://, DBI->data_sources('mysql', $self->connection_params);

  croak 'ERROR: failed to retrieve a list of data sources'
    unless scalar @sources;

  return \@sources;
}

#---------------------------------------

=attr available_database_schemas

A reference to an array containing L<DBIx::Class::Schema|DBIC schema> objects
for the available databases, as given by L<available_database_names>.

See L<available_database_names> for an explanation of what constitutes an
"available" database.

=cut

has 'available_database_schemas' => (
  is      => 'ro',
  isa     => ArrayRef[BioTrackSchema],
  lazy    => 1,
  writer  => '_set_available_database_schemas',
  builder => '_build_available_database_schemas',
);

  # NOTE This could be horrible memory hungry. If we create a new schema object
  # for every N databases and each one used M mb of memory, we could end up
  # using N * M mb if we do this. It might be safer to generate and destroy
  # each schema in turn

  # TODO profile this and see how bad it is

sub _build_available_database_schemas {
  my $self = shift;

  my $db_list = $self->available_database_names;

  my @schemas;
  foreach my $db_name ( @$db_list ) {
    my $schema = $self->get_schema($db_name);
    next unless defined $schema;
    push @schemas, $schema;
  }

  return \@schemas;
}

#---------------------------------------

=attr available_database_names

A reference to an array containing the names of live, searchable, production
pathogen databases.

In order to appear in this list a database must:

=over

=item exist in the list of data sources (see L<data_sources>)

=item have an associated directory structure (see L<Bio::Path::Find::Path::get_hierarchy_root_dir>).

=back

The list will be sorted to put "track" databases first, e.g.
C<pathogen_euk_track>, followed by "external" databases, and finally the
production databases will be moved to the top of this, so that they may be
searched first.

=cut

has 'available_database_names' => (
  is      => 'ro',
  isa     => ArrayRef[Str],
  lazy    => 1,
  writer  => '_set_available_database_names',
  builder => '_build_available_database_names',
);

sub _build_available_database_names {
  my $self = shift;

  my $db_list = [];
  push @$db_list, grep /^pathogen_.+_track$/,    @{ $self->data_sources };
  push @$db_list, grep /^pathogen_.+_external$/, @{ $self->data_sources };

  # this will be the list of all databases in the MySQL instance, ordered with
  # "track" DBs first, then "external", and then re-ordered according to the
  # database names given in the "production_db" slot in the config
  $db_list = $self->_reorder_db_list($db_list);

  # this will be the list of databases for which we have an associated
  # directory on disk
  my @db_list_out;

  foreach my $database_name ( @$db_list ) {
    my $root_dir = $self->_path->get_hierarchy_root_dir($database_name);
    next unless defined $root_dir;
    push @db_list_out, $database_name;
  }

  return \@db_list_out;
}

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

has '_path' => (
  is      => 'ro',
  isa     => BioPathFindPath,
  lazy    => 1,
  default => sub {
    my $self = shift;
    Bio::Path::Find::Path->new(
      environment => $self->environment,
      config_file => $self->config_file
    );
  }
);

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 get_schema($database_name)

Returns a L<Bio::Track::Schema> object for the specified database. If we can't
connect to the database, or if there is no accompanying directory hierarchy, as
specified in the config, the method returns C<undef>.

=cut

sub get_schema {
  my ( $self, $db_name ) = @_;

  my %pathogen_database_names = map { $_ => 1 } @{ $self->available_database_names };

  return unless $pathogen_database_names{$db_name};

  my $c = $self->_config->{connection_params};
  my $schema;
  if ( $self->environment eq 'test' ) {
    croak 'ERROR: must specify SQLite DB location as "connection:dbname" in test config'
      unless $c->{dbname};
    $schema = Bio::Track::Schema->connect('dbi:SQLite:dbname=' . $c->{dbname});
  }
  else {
    my $dsn = 'DBI:mysql:'
            . "host=$c->{host};"
            . "port=$c->{port};"
            . "database=$db_name";
    my $user = $c->{user};
    my $pass = $c->{pass} || undef;
    $schema = Bio::Track::Schema->connect($dsn, $user, $pass);
  }

  return $schema;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# re-order the provided list of database names to move production databases to
# the top. The list of production databases is taken from the 'production_dbs'
# attribute.

sub _reorder_db_list {
  my ( $self, $db_list ) = @_;

  my @reordered_db_list;

  my %db_list_lookup = map { $_ => 1 } @$db_list;

  # first, add production databases to the output list
  foreach my $database_name ( @{ $self->production_dbs } ) {
    next unless $db_list_lookup{$database_name};
    push @reordered_db_list, $database_name;

    # remove already added DBs from the lookup, so that we can add the
    # remainder below
    delete $db_list_lookup{$database_name};
  }

  # add remaining DBs to output
  foreach my $database_name (sort keys %db_list_lookup ) {
    push @reordered_db_list, $database_name;
  }

  return \@reordered_db_list;
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

