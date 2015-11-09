
package Bio::Path::Find;

use v5.10; # required for Type::Params use of "state"

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw( croak carp );
use File::Slurper qw( read_lines );
use Path::Class;

use Type::Params qw( compile );
use Types::Standard qw(
  Object
  HashRef
  ArrayRef
  Str
  Int
  slurpy
  Dict
  Optional
);
use Type::Utils qw( enum );
use Bio::Path::Find::Types qw(
  BioPathFindSorter
  IDType
  FileIDType
  QCState
  FileType
  Environment
);

use Log::Log4perl;

BEGIN {
  my $logger_conf = q(
    log4perl.appender.Screen                          = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.layout                   = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Screen.layout.ConversionPattern = %M:%L %p: %m%n

    log4perl.logger.Bio.Path.Find                     = ERROR, Screen
    log4perl.logger.Bio.Path.Find.Lane                = ERROR, Screen
    log4perl.logger.Bio.Path.Find.DatabaseManager     = ERROR, Screen

    log4perl.oneMessagePerAppender                    = 1
  );
  Log::Log4perl->init_once(\$logger_conf);
}

use Bio::Path::Find::DatabaseManager;
use Bio::Path::Find::Lane;
use Bio::Path::Find::Sorter;

with 'Bio::Path::Find::Role::HasEnvironment',
     'Bio::Path::Find::Role::HasConfig',
     'MooseX::Log::Log4perl';

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

Inherits C<config> and C<environment> from the roles
L<Bio::Path::Find::Role::HasConfig> and
L<Bio::Path::Find::Role::HasEnvironment>.

=cut

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# somewhere to store the list of IDs that we'll search for. This could be just
# a single ID from the command line or many IDs from a file
has '_ids' => (
  traits  => ['Array'],
  is      => 'ro',
  isa     => ArrayRef[Str],
  default => sub { [] },
  handles => {
    '_add_id'    => 'push',
    '_clear_ids' => 'clear',
  }
);

#---------------------------------------

# the actual type of the IDs we'll be searching for, since we can't rely on
# "type" to give us that
has '_id_type' => (
  is      => 'rw',
  isa     => IDType,
  default => 'lane',
);

#---------------------------------------

has '_db_manager' => (
  is      => 'ro',
  isa     => 'Bio::Path::Find::DatabaseManager',
  lazy    => 1,
  builder => '_build_db_manager',
);

sub _build_db_manager {
  my $self = shift;
  return Bio::Path::Find::DatabaseManager->new(
    environment => $self->environment,
    config      => $self->config,
  );
}

#---------------------------------------

has '_sorter' => (
  is      => 'rw',
  isa     => BioPathFindSorter,
  lazy    => 1,
  default => sub {
    my $self = shift;
    Bio::Path::Find::Sorter->new(
      environment => $self->environment,
      config      => $self->config,
    );
  },
);

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

sub find {
  state $check = compile(
    Object,
    slurpy Dict[
      id           => Str,
      type         => IDType,
      file_id_type => Optional[FileIDType],
      qc           => Optional[QCState],
      filetype     => Optional[FileType],
    ],
  );
  my ( $self, $params ) = $check->(@_);

  # check for dependencies between parameters: if "type" is "file", we need to
  # know what type of IDs we'll find in the file
  croak qq(ERROR: if "type" is "file", you must also specify "file_id_type")
    if ( $params->{type} eq 'file' and not $params->{file_id_type} );

  #---------------------------------------

  # we can't use "type" to tell us what kind of IDs we're working with, since
  # it can be set to "file", in which case we need to look at "file_id_type"
  # to get the type of IDs in the file...

  $self->_clear_ids;

  if ( $params->{type} eq 'file' ) {
    # read multiple IDs from a file
    $self->_load_ids_from_file($params->{id});
    $self->_id_type($params->{file_id_type});

    $self->log->info('finding multiple IDs from file ' . $params->{id}
                     . ' of type "' . $params->{file_id_type} . '"');
  }
  else {
    # use the single ID from the command line
    # push @{ $self->_ids }, $params->{id};
    $self->_add_id( $params->{id} );
    $self->_id_type($params->{type});

    $self->log->info('finding IDs "' . $params->{id} . '"'
                     . ' of type "' . $params->{type} . '"');
  }

  #---------------------------------------

  # get a list of Bio::Path::Find::Lane objects
  my $lanes = $self->_find_lanes;

  $self->log->info('found ' . scalar @$lanes . ' lanes');

  # find files for the lanes
  my $filtered_lanes = [];
  LANE: foreach my $lane ( @$lanes ) {

    # ignore this lane if:
    # 1. we've been told to look for a specific QC status, and
    # 2. the lane has a QC status set, and
    # 3. this lane's QC status doesn't match the required status
    if ( defined $params->{qc} and
         defined $lane->row->qc_status and
         $lane->row->qc_status ne $params->{qc} ) {
      $self->log->debug(
        'lane "' . $lane->row->name
        . '" filtered by QC status (actual status is "' . $lane->row->qc_status
        . '"; requiring status "' . $params->{qc} . '")'
      );
      next LANE;
    }

    # return lanes that have a specific type of file
    if ( $params->{filetype} ) {
      $lane->find_files($params->{filetype});
      if ( $lane->has_files ) {
        push @$filtered_lanes, $lane;
      }
      else {
        $self->log->debug('lane "' . $lane->row->name . '" has no files of type "'
                          . $params->{filetype} . '"; filtered out');
      }
    }
    # we don't care about files; return all lanes
    else {
      push @$filtered_lanes, $lane;
      $self->log->debug('showing lane directories');
    }
  }

  # at this point we have a list of Bio::Path::Find::Lane objects, each of
  # which has a QC status matching the supplied QC value. Each lane has also
  # gone off to look for the files associated with its row in the database

  my $sorted_lanes = $self->_sorter->sort_lanes($filtered_lanes);

  # TODO generate stats

  return $sorted_lanes; # array of lane objects
}

#-------------------------------------------------------------------------------

sub print_paths {
  state $check = compile(
    Object,
    slurpy Dict[
      id           => Str,
      type         => IDType,
      file_id_type => Optional[FileIDType],
      qc           => Optional[QCState],
      filetype     => Optional[FileType],
    ],
  );
  my ( $self, $params ) = $check->(@_);

  my $lanes = $self->find(%$params);

  my $found_something = 0;
  foreach my $lane ( @$lanes ) {
    $found_something += $lane->print_paths;
  }

  say 'Could not find lanes or files for input data'
    unless $found_something;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

sub _load_ids_from_file {
  my ( $self, $filename ) = @_;

  croak "ERROR: no such file ($filename)"
    unless -f $filename;

  # TODO check if this will work with the expected usage. If users are used
  # TODO to putting plex IDs as search terms, stripping lines starting with
  # TODO "#" will break those searches
  my @ids = grep ! m/^#/, read_lines($filename);

  croak "ERROR: no IDs found in file ($filename)"
    unless scalar @ids;

  # push @{ $self->_ids }, @ids;
  $self->_add_id(@ids);
}

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

  # somewhere to store all of the Bio::Path::Find::Lane objects that we're
  # going to build
  my @lanes;

  # TODO if we wanted to parallelise the database searching, this is where it
  # TODO needs to happen... I've tried using Parallel::ForkManager but it's not
  # TODO working for some reason that I can't immediately fathom

  # TODO need to sort the list of databases according to the order of
  # TODO the names in the "production_db" array in the config, and putting
  # TODO "track" before "external", etc.

  DB: foreach my $db_name ( $self->_db_manager->database_names ) {
    $self->log->debug(qq(searching "$db_name"));

    my $database = $self->_db_manager->get_database($db_name);

    ID: foreach my $id ( @{ $self->_ids } ) {
      $self->log->debug(qq(looking for ID "$id"));

      my $rs = $database->schema->get_lanes_by_id($id, $self->_id_type);
      next ID unless $rs; # no matching lanes

      $self->log->debug('found ' . $rs->count . ' lanes');

      while ( my $lane_row = $rs->next ) {

        # tell every result (a Bio::Track::Schema::Result object) which
        # database it comes from. We need this later to generate paths on disk
        # for the files associated with each result
        $lane_row->database($database);

        # build a lightweight object to hold all of the data about a particular
        # row
        my $lane = Bio::Path::Find::Lane->new( row => $lane_row );

        push @lanes, $lane;
      }
    }

    # TODO this needs more consideration...
    # last DB unless $always_search->{$db_name};
  }

  return \@lanes;
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

