
package Bio::Path::Find::Path;

# ABSTRACT: class to handle interactions with the pathogens data directory structures

use Moo;
use MooX::StrictConstructor;

use Types::Standard qw( Str HashRef );
use Carp qw( croak carp );

with 'Bio::Path::Find::Role::HasEnvironment',
     'Bio::Path::Find::Role::HasConfig';

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

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
  my $db_root = $self->_config->{db_root};

  if ( not defined $db_root ) {
    carp 'WARNING: configuration (' . $self->config_file
         . ') does not specify the path to the root directory containing data directories ("db_root"); using default';
    $db_root = $self->environment eq 'test'
             ? 't/data/04_find_path/root_dir'
             : '/lustre/scratch108/pathogen/pathpipe';
  }

  croak "ERROR: data hierarchy root directory ($db_root) does not exist (or is not a directory)"
    unless -d $db_root;

  return $db_root;
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
  writer  => '_set_db_subdirs',
  builder => '_build_db_subdirs',
);

sub _build_db_subdirs {
  my $self = shift;

  # try to find the mapping in the config
  my $db_subdirs = $self->_config->{db_subdirs};

  if ( not defined $db_subdirs ) {
    carp 'WARNING: configuration (' . $self->config_file
         . ') does not specify the mapping between database name and sub-directory ("db_subdirs"); using default';
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
  writer  => '_set_hierarchy_template',
  builder => '_build_hierarchy_template',
);

sub _build_hierarchy_template {
  my $self = shift;

  # find the template for the directory hierarchy in the config
  my $template = $self->_config->{hierarchy_template};

  if ( not defined $template ) {
    carp 'WARNING: configuration (' . $self->config_file
         . ') does not specify the directory hierarchy template ("template"); using default';
    $template = 'genus:species-subspecies:TRACKING:projectssid:sample:technology:library:lane';
  }

  croak "ERROR: invalid directory hierarchy template ($template)"
    unless $template =~ m/^([\w-]+:?)+$/;

  return $template;
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 get_hierarchy_root_dir($database_name)

Returns the root directory for the directory hierarchy that is associated with
the given tracking database, e.g.

  my $pf = Path::Find->new;
  my $root_dir = $pf->hierarchy_root_dir($database_name);

Returns the path to the root of the directory hierarchy, or C<undef> if the
directory does not exist.

=cut

sub get_hierarchy_root_dir {
  my ( $self, $database_name ) = @_;

  croak 'ERROR: must specify a database name' unless $database_name;

  my $sub_dir            = $self->get_tracking_name_from_database_name($database_name);
  my $hierarchy_root_dir = $self->db_root . "/$sub_dir/seq-pipelines";

  return ( -d $hierarchy_root_dir )
         ? $hierarchy_root_dir
         : undef;
}

#-------------------------------------------------------------------------------

=head2 get_tracking_name_from_database_name($database_name)

This method looks up the name of a database in the database-to-sub-directory
mapping in the attribute C<db_subdirs>.

If the given database has a differently named sub-directory, according to the
mapping, the method returns the name of that sub-directory.

If the given database does not appear in the mapping, its subdirectory in
the directory hierarchy matches the database name, so the method simply
returns the database name.

=cut

sub get_tracking_name_from_database_name {
  my ( $self, $database_name ) = @_;

  return exists $self->db_subdirs->{$database_name}
         ? $self->db_subdirs->{$database_name}
         : $database_name;
}

#-------------------------------------------------------------------------------

1;

