
package Bio::Path::Find;

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw( croak carp );
use File::Slurp;
use File::Spec;

# TODO this should allow short options but isn't working for some reason
use Getopt::Long qw( :config auto_abbrev );

use Types::Standard qw( ArrayRef Str );
use Type::Utils qw( enum );
use Type::Params qw( compile );
use Bio::Path::Find::Types qw(
  BioPathFindDatabase
  BioPathFindFilter
  BioPathFindSorter
  Environment
  IDType
);

use Bio::Path::Find::DatabaseManager;
use Bio::Path::Find::Database;
use Bio::Path::Find::Filter;
use Bio::Path::Find::Sorter;

with 'Bio::Path::Find::Role::HasEnvironment',
     'Bio::Path::Find::Role::HasConfig',
     'MooseX::Getopt';

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------
#- command-line options --------------------------------------------------------
#-------------------------------------------------------------------------------

has 'id' => (
  is            => 'ro',
  isa           => Str,
  required      => 1,
  documentation => 'lane, sample or study ID, or name of file containing IDs',
);

has 'type' => (
  is      => 'ro',
  isa     => IDType,
  default => 'lane',
  documentation =>
    'ID type; must be one of: study, lane, file, library, sample, species',
);

has 'file_id_type' => (
  is            => 'ro',
  isa           => enum( [qw( lane sample )] ),
  default       => 'lane',
  documentation => 'type of IDs in file; must be either "lane" or "sample"',
);

# we also get "config" and "environment" from the two roles that we use

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

has '_db_manager' => (
  is => 'ro',
  isa => 'Bio::Path::Find::DatabaseManager',
  lazy => 1,
  builder => '_build_db_manager',
);

sub _build_db_manager {
  my $self = shift;
  return Bio::Path::Find::DatabaseManager->new(
    environment => $self->environment,
    config      => $self->config,
  );
}

has '_filter'    => ( is => 'rw', isa => BioPathFindFilter );
has '_sorter'    => ( is => 'rw', isa => BioPathFindSorter );

#---------------------------------------

# somewhere to store the list of IDs that we'll search for. This could be just
# a single ID from the command line or many IDs from a file
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

  my $e = $self->environment;
  my $c = $self->config_file;

  $self->_filter( Bio::Path::Find::Filter->new( environment => $e, config_file => $c ) );
  $self->_sorter( Bio::Path::Find::Sorter->new( environment => $e, config_file => $c ) );
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

sub find {
  my $self = shift;

  foreach my $lane ( @{ $self->_find_lanes } ) {

    # from which database is the lane derived ?
    my $database = $self->_db_manager->get_database( $lane->database_name );

    # what is the root directory for files associated with that directory ?
    my $root = $database->hierarchy_root_dir;

    # what is the path for files for this specific lane ?
    my $path = $lane->path;

    # TODO switch to using Path::Class instead of File::Spec
    print File::Spec->catdir($root, $path), "\n";

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

  # (this is just a workaround for Config::General's stupid handling of
  # single-item lists)
  if ( $self->config->{always_search} ) {
    my $as = $self->config->{always_search};
    if ( ref $as eq 'ARRAY' ) {
      $always_search->{$_} = 1 for ( @$as );
    }
    else {
      $always_search->{$as} = 1;
    }
  }

  # walk over the list of available databases and, for each ID, search for
  # lanes matching the specified ID

  # somewhere to store all of the Bio::Track::Schema::Result::LatestLane
  # objects that we find
  my @results;

  # TODO if we wanted to parallelise the database searching, this is
  # TODO where it needs to happen...
  DB: foreach my $db_name ( $self->_db_manager->database_names ) {
    my $database = $self->_db_manager->get_database($db_name);

    # the results for this database
    my $db_results = [];

    ID: foreach my $id ( @{ $self->_ids } ) {
      my $rs = $database->schema->get_lanes_by_id($id, $self->_id_type);
      next ID unless $rs;
      while ( my $result = $rs->next ) {
        # tell every result (a Bio::Track::Schema::Result object) which
        # database it comes from. We need this later to generate paths on disk
        # for the files associated with each result
        $result->database_name($db_name);
        push @$db_results, $result;
      }
    }

    # move on to the next database unless we got some results
    next DB unless scalar @$db_results;

    $db_results = $self->_filter->filter_lanes($db_results);

    $db_results = $self->_sorter->sort_lanes($db_results);

    # TODO generate stats

    push @results, @$db_results;

    # TODO this needs more consideration...
    # last DB unless $always_search->{$db_name};
  }

  return \@results;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
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

__PACKAGE__->meta->make_immutable;

1;

