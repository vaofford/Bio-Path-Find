
package Bio::Path::Find::Database;

# ABSTRACT: class to handle interactions with a specific pathogens tracking database

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
  Undef
);
use Bio::Path::Find::Types qw(
  BioTrackReducedSchema
  PathClassDir
  DirFromStr
);

use Bio::Track::ReducedSchema;
use Bio::Path::Find::Exception;

with 'Bio::Path::Find::Role::HasConfig';

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

The configuration must contain the parameter C<dsn>, giving the L<DBI> DSN
string for the database. If the connection requires a username and/or password,
C<user> and C<pass> must also be given, e.g.

  <connection_params>
    dsn  dbi:SQLite:dbname=t/data/pathogen_prod_track.db
  </connection_params>

for a SQLite database, or

  <connection_params>
    dsn  DBI:mysql=host=test_db_host;port=3306;database=pathogen_prok_track
    user test_db_username
    pass test_db_password
  </connection_params>

for a MySQL database.

B<Read only>.

=cut

has 'schema' => (
  is      => 'ro',
  isa     => BioTrackReducedSchema,
  lazy    => 1,
  builder => '_build_schema',
);

sub _build_schema {
  my $self = shift;

  my $c    = $self->config->{connection_params};

  my $dsn  = $self->_get_dsn;
  my $user = $c->{user};
  my $pass = $c->{pass};

  my $schema;
  if ( $c->{driver} eq 'mysql' ) {
    $schema = Bio::Track::ReducedSchema->connect($dsn, $user, $pass);
  }
  elsif ( $c->{driver} eq 'SQLite' ) {
    $schema = Bio::Track::ReducedSchema->connect($dsn);
  }

  return $schema;
}

#---------------------------------------

=attr db_root

Every database must have an associated directory, which contains the flat files
that store the data. The C<db_root> attribute gives the root of this directory
hierarchy. The root directory should be specified in the configuration file,
using the key C<db_root>.

If C<db_root> is not found in the config, an exception is thrown. If the config
specifies a directory but the directory doesn't exist (or isn't a directory),
an exception is thrown.

B<Read-only>.

=cut

has 'db_root' => (
  is       => 'ro',
  isa      => PathClassDir->plus_coercions(DirFromStr),
  coerce   => 1,
  lazy     => 1,
  writer   => '_set_db_root',
  builder  => '_build_db_root',
);

sub _build_db_root {
  my $self = shift;

  # find the root directory for the directory structure containing the data
  my $db_root = dir $self->config->{db_root};

  Bio::Path::Find::Exception->throw(
    msg => "ERROR: data hierarchy root directory is not defined in the configuration" )
    unless defined $db_root;

  Bio::Path::Find::Exception->throw(
    msg => "ERROR: data hierarchy root directory ($db_root) does not exist (or is not a directory)" )
    unless -d $db_root;

  return $db_root;
}

#---------------------------------------

=attr hierarchy_template

Template for the directory hierarchy where flat files are stored. Must be a
colon-separated list of directory names.

If C<hierarchy_template> is not specified in the configuration, we use the
following default:

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

  # fall back on a default setting
  $template ||= 'genus:species-subspecies:TRACKING:projectssid:sample:technology:library:lane';

  Bio::Path::Find::Exception->throw( msg => "ERROR: invalid directory hierarchy template ($template)" )
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

If C<db_subdirs> is not found in the configuration, we use the following
default mapping:

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

  # try to find the mapping in the config...
  my $db_subdirs = $self->config->{db_subdirs};

  # ... or fall back on the hard-coded version
  $db_subdirs ||= {
    pathogen_virus_track    => 'viruses',
    pathogen_prok_track     => 'prokaryotes',
    pathogen_euk_track      => 'eukaryotes',
    pathogen_helminth_track => 'helminths',
    pathogen_rnd_track      => 'rnd',
  };

  return $db_subdirs;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# returns the DSN based on the connection parameters in the config

sub _get_dsn {
  my $self = shift;

  Bio::Path::Find::Exception->throw(
    msg => 'ERROR: must specify database connection parameters in configuration' )
    unless exists $self->config->{connection_params};

  my $c = $self->config->{connection_params};

  Bio::Path::Find::Exception->throw(
    msg => 'ERROR: must specify a database driver in connection parameters configuration' )
    unless exists $c->{driver};

  my $dsn;

  if ( $c->{driver} eq 'mysql' ) {

    # make sure all of the required connection parameters are supplied
    foreach my $param ( qw( host port user ) ) {
      Bio::Path::Find::Exception->throw( msg => "ERROR: missing connection parameter, $param" )
        unless exists $c->{$param};
    }

    $dsn = "DBI:mysql:host=$c->{host};port=$c->{port};database=" . $self->name;
  }
  elsif ( $c->{driver} eq 'SQLite' ) {
    Bio::Path::Find::Exception->throw( msg => "ERROR: missing connection parameter, dbname" )
      unless exists $c->{dbname};
    $dsn = "dbi:SQLite:dbname=$c->{dbname}";
  }
  else {
    Bio::Path::Find::Exception->throw(
      msg => "ERROR: not a valid database driver; must be either 'mysql' or 'SQLite'"
    );
  }

  return $dsn;
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

