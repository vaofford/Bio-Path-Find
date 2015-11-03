
package Bio::Path::Find::Database;

# ABSTRACT: class to handle interactions with a specific pathogens tracking database

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Types::Standard qw( Str ArrayRef HashRef Undef );
use Carp qw( croak carp );
use DBI;

use Bio::Track::Schema;
use Bio::Path::Find::Types qw( BioTrackSchema );

with 'Bio::Path::Find::Role::HasEnvironment',
     'Bio::Path::Find::Role::HasConfig';

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

=attr name

The name of the database handled by this object.

B<Read only>.

=cut

has 'name' => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

#---------------------------------------

=attr schema

The L<Bio::Track::Schema> object for the database handled by this object.
Connection parameters are taken from the configuration.
In production, the database is assumed to be a MySQL instance. The
configuration must contain the parameters C<host>, C<port>, and C<user>. If
the connection requires a password, C<pass> must also be given, e.g.

  <connection_params>
    host dbhost
    port 3306
    user find_user
  </connection_params>

In a test environment, the database is assumed to be an SQLite DB file, in
which case the configuration block must contain the key C<dbname>. The
C<host>, C<port>, and C<user> keys must be present but can contain dummy
values, e.g.

  <connection_params>
    dbname test_database.db
    host host
    port 3306
    user user
  </connection_params>

B<Read only>.

=cut

has 'schema' => (
  is      => 'ro',
  isa     => BioTrackSchema,
  lazy    => 1,
  builder => '_build_schema',
);

sub _build_schema {
  my $self = shift;

  my $dsn = $self->_get_dsn;

  my $user = $self->config->{connection_params}->{user};
  my $pass = $self->config->{connection_params}->{pass} || undef;
  my $schema = $self->is_test_env
             ? Bio::Track::Schema->connect($dsn)
             : Bio::Track::Schema->connect($dsn, $user, $pass);

  return $schema;
}

#---------------------------------------

=attr db_root

Every database must have an associated directory, which contains the flat files
that store the data. The C<db_root> attribute gives the root of this directory
hierarchy. The root directory should be specified in the configuration file,
using the key C<db_root>.

If C<db_root> is not found in the config, a warning is issued and we use a
default value: if the C<environment> attribute is set to C<test>, C<db_root>
defaults to a directory in the test suite, otherwise the default is a
Sanger-specific disk location.

B<Read-only>.

=cut

has 'db_root' => (
  is       => 'ro',
  isa      => Str,
  lazy     => 1,
  writer   => '_set_db_root',
  builder  => '_build_db_root',
);

sub _build_db_root {
  my $self = shift;

  # find the root directory for the directory structure containing the data
  my $db_root = $self->config->{db_root};

  if ( not defined $db_root ) {
    carp 'WARNING: configuration does not specify the path to the root directory containing data directories ("db_root"); using default';
    $db_root = $self->environment eq 'test'
             ? 't/data/04_database/root_dir'
             : '/lustre/scratch108/pathogen/pathpipe';
  }

  croak "ERROR: data hierarchy root directory ($db_root) does not exist (or is not a directory)"
    unless -d $db_root;

  return $db_root;
}

#---------------------------------------

=attr hierarchy_template

Template for the directory hierarchy where flat files are stored. Must be a
colon-separated list of directory names.

If C<hierarchy_template> is not specified in the configuration, a warning is
issued and we use the following default:

  genus:species-subspecies:TRACKING:projectssid:sample:technology:library:lane

B<Read-only>.

=cut

has 'hierarchy_template' => (
  is      => 'ro',
  isa     => Str,
  lazy    => 1,
  builder => '_build_hierarchy_template',
);

sub _build_hierarchy_template {
  my $self = shift;

  # find the template for the directory hierarchy in the config
  my $template = $self->config->{hierarchy_template};

  if ( not defined $template ) {
    carp 'WARNING: configuration does not specify the directory hierarchy template ("template"); using default';
    $template = 'genus:species-subspecies:TRACKING:projectssid:sample:technology:library:lane';
  }

  croak "ERROR: invalid directory hierarchy template ($template)"
    unless $template =~ m/^([\w-]+:?)+$/;

  return $template;
}

#---------------------------------------

=head2 hierarchy_root_dir

The root of the directory hierarchy that is associated with the given tracking
database. C<undef> if the directory does not exist. The generation of the
hierarchy root directory path takes into account the sub-directory mapping.
See L<db_subdirs>.

=cut

has 'hierarchy_root_dir' => (
  is      => 'ro',
  isa     => Str | Undef,
  lazy    => 1,
  writer  => '_set_hierarchy_root_dir',
  builder => '_build_hierarchy_root_dir',
);

sub _build_hierarchy_root_dir {
  my $self = shift;

  my $sub_dir = exists $self->db_subdirs->{$self->name}
              ? $self->db_subdirs->{$self->name}
              : $self->name;

  my $hierarchy_root_dir = $self->db_root . "/$sub_dir/seq-pipelines";

  return ( -d $hierarchy_root_dir )
         ? $hierarchy_root_dir
         : undef;
}

#---------------------------------------

=attr db_subdirs

It's possible for a given database to have a sub-directory with a different
name in the data directories. This attribute specifies the mapping between
database name and subdirectory name.

If C<db_subdirs> is not found in the configuration, a warning is issued and we
use the following default mapping:

  pathogen_virus_track    => 'viruses',
  pathogen_prok_track     => 'prokaryotes',
  pathogen_euk_track      => 'eukaryotes',
  pathogen_helminth_track => 'helminths',
  pathogen_rnd_track      => 'rnd',

B<Read-only>.

=cut

has 'db_subdirs' => (
  is      => 'ro',
  isa     => HashRef,
  lazy    => 1,
  builder => '_build_db_subdirs',
);

sub _build_db_subdirs {
  my $self = shift;

  # try to find the mapping in the config
  my $db_subdirs = $self->config->{db_subdirs};

  if ( not defined $db_subdirs ) {
    carp 'WARNING: configuration does not specify the mapping between database name and sub-directory ("db_subdirs"); using default';
    $db_subdirs = {
      pathogen_virus_track    => 'viruses',
      pathogen_prok_track     => 'prokaryotes',
      pathogen_euk_track      => 'eukaryotes',
      pathogen_helminth_track => 'helminths',
      pathogen_rnd_track      => 'rnd',
    };
  }

  return $db_subdirs;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# returns the DSN based on the connection parameters in the config

sub _get_dsn {
  my $self = shift;

  my $c = $self->config->{connection_params};

  my $dsn;
  if ( $self->environment eq 'test' ) {
    croak 'ERROR: must specify SQLite DB location as "connection:dbname" in test config'
      unless $c->{dbname};
    $dsn = 'dbi:SQLite:dbname=' . $c->{dbname};
  }
  else {
    $dsn = 'DBI:mysql:'
           . "host=$c->{host};"
           . "port=$c->{port};"
           . 'database=' . $self->name;
  }

  return $dsn;
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

