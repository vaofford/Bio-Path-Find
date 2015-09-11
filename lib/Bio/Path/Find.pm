
package Bio::Path::Find;

use v5.10;

use Moo;
use MooX::StrictConstructor;
use MooX::Options;

use Carp qw( croak carp );
use File::Slurp;

use Types::Standard qw( ArrayRef Str );
use Type::Utils qw( enum );
use Type::Params qw( compile );
use Bio::Path::Find::Types qw(
  BioPathFindPath
  BioPathFindDatabase
  Environment
  IDType
);

use Bio::Path::Find::Path;
use Bio::Path::Find::Database;

with 'Bio::Path::Find::Role::HasEnvironment',
     'Bio::Path::Find::Role::HasConfig';

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------
#- command-line options --------------------------------------------------------
#-------------------------------------------------------------------------------

option 'id' => (
  is       => 'ro',
  isa      => Str,
  required => 1,
  doc      => 'lane, sample or study ID, or name of file containing IDs',
);

option 'type' => (
  is      => 'ro',
  isa     => IDType,
  default => 'lane',
  doc     => 'ID type; must be one of: study, lane, file, library, sample, species',
);

option 'file_id_type' => (
  is      => 'ro',
  isa     => enum( [qw( lane sample )] ),
  default => 'lane',
  doc     => 'type of IDs in file; must be either "lane" or "sample"',
);

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

has '_find_path' => (
  is      => 'ro',
  isa     => BioPathFindPath,
  lazy    => 1,
  writer  => '_set_find_path',
  builder => '_build_find_path',
);

sub _build_find_path {
  my $self = shift;
  return Bio::Path::Finder::Path->new(
    environment => $self->environment,
    config_file => $self->config_file,
  );
}

#---------------------------------------

has '_find_db' => (
  is      => 'ro',
  isa     => BioPathFindDatabase,
  lazy    => 1,
  writer  => '_set_find_db',
  builder => '_build_find_db',
);

sub _build_find_db {
  my $self = shift;
  return Bio::Path::Find::Database->new(
    environment => $self->environment,
    config_file => $self->config_file,
  );
}

#---------------------------------------

# somewhere to store the list of IDs that we'll search for. This could be just
# a single ID or many IDs from a file
has '_ids' => (
  is      => 'ro',
  isa     => ArrayRef[Str],
  default => sub { [] },
);

#---------------------------------------

# the actual type of the IDs we'll be searching for, since we can't rely on
# "type" to give us that
has '_id_type' => (
  is      => 'rw',
  isa     => enum( [ qw( lane sample ) ] ),
  default => 'lane',
);

#-------------------------------------------------------------------------------
#- construction ----------------------------------------------------------------
#-------------------------------------------------------------------------------

sub BUILD {
  my $self = shift;

  # if "type" is "file", we need to know what type of IDs we'll find in the
  # file
  croak qq(ERROR: if "type" is "file", you must also specify "file_id_type")
    if ( $self->type eq 'file' and not $self->file_id_type );

  # we can't use "type" to tell us reliably what kind of IDs we're working
  # with, since it can be set to "file", in which case we need to look to
  # "file_id_type" for type of IDs in the file...

  if ( $self->type eq 'file' ) {
    $self->_load_ids_from_file($self->id);
    $self->_id_type($self->file_id_type);
  }
  else {
    push @{ $self->_ids }, $self->id;
    $self->_id_type($self->type);
  }

}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

# TODO this method needs to convert $lane->storage_path into a path to the
# TODO symlinked directory hierarchy. The actual code to do the mapping should
# TODO be bolted onto Bio::Path::Find::Path
#
# sub paths {
#   my $self = shift;
#
#   my $lanes = $self->_find_lanes;
#
# }

#-------------------------------------------------------------------------------

sub find {
  my $self = shift;

  my $lanes = $self->_find_lanes;

  foreach my $lane ( $lanes->all ) {
    print $lane->storage_path, "\n";
  }

}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

sub _find_lanes {
  my $self = shift;

  # look in the config and see if there's a database (or more than one) that
  # must always be searched, e.g. pathogen_pacbio_track
  my $always_search = {};

  # this is a workaround for Config::General's stupid handling of single-item
  # lists
  if ( $self->_config->{always_search} ) {
    my $as = $self->_config->{always_search};
    if ( ref $as eq 'ARRAY' ) {
      $always_search->{$_} = 1 for ( @$as );
    }
    else {
      $always_search->{$as} = 1;
    }
  }

  my $available_schemas  = $self->_find_db->available_database_schemas;
  my $available_db_names = $self->_find_db->available_database_names;

  # walk over the list of available database schemas and, for each ID,
  # search for lanes matching the specified ID

  my $rs;
  DB: foreach my $i ( 0 .. $#$available_db_names ) {
                         # ^^^ see http://www.perlmonks.org/?node_id=624502
    my $schema  = $available_schemas->[$i];
    my $db_name = $available_db_names->[$i];

    ID: foreach my $id ( @{ $self->_ids } ) {

      $rs = $schema->get_lanes_by_id($id, $self->_id_type);
      next DB unless ( defined $rs and $rs->count );

      # TODO filter lanes

      # TODO sort lanes

      # TODO generate stats

      last DB unless $always_search->{$db_name};
    }
  }

  return $rs;
}

#-------------------------------------------------------------------------------

sub _load_ids_from_file {
  my ( $self, $filename ) = @_;

  croak "ERROR: no such file ($filename)"
    unless -f $filename;

  my @ids = grep m/^#/, read_file($filename);

  croak "ERROR: no IDs found in file ($filename)"
    unless scalar @ids;

  push @{ $self->_ids }, @ids;
}

#-------------------------------------------------------------------------------

1;
