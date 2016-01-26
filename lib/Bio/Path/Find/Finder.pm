
package Bio::Path::Find::Finder;

# ABSTRACT: find information about sequencing lanes

use v5.10; # required for Type::Params use of "state"

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw( carp );
use Path::Class;
use File::Basename;
use Try::Tiny;
use Scalar::Util qw( blessed );

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
  Maybe
);
use Type::Utils qw( enum );
use Bio::Path::Find::Types qw(
  BioPathFindSorter
  IDType
  FileIDType
  QCState
  FileType
);

use Bio::Path::Find::DatabaseManager;
use Bio::Path::Find::Lane;
use Bio::Path::Find::Sorter;
use Bio::Path::Find::Exception;

with 'MooseX::Log::Log4perl',
     'Bio::Path::Find::Role::HasConfig',
     'Bio::Path::Find::Role::HasProgressBar';

=head1 CONTACT

path-help@sanger.ac.uk

=cut

=head1 SYNOPSIS

  # create a Finder object by handing it a config hash
  my $finder = Bio::Path::Find::Finder->new(
    config => $config_hashref
  );

  # get an arrayref of Bio::Path::Find::Lane objects matching search criteria
  my $lanes = $finder->find_lanes(
    ids  => [ qw( 12345_1 2345 ) ],
    type => 'lane',
  );

=head1 DESCRIPTION

This is the main class for retrieving lane information from the pathogen
tracking databases. It requires a config that provides database connection
parameters, e.g.

  <connection_params>
    <tracking>
      driver mysql
      host   path-db
      port   3306
      user   pathogens
      schema Bio::Track::Schema
    </tracking>
  </connection_params>

The configuration may be specified using C<config_file>, in which case the
configuration will be read from the specified file, or using C<config>, with
the config provided as a hashref.

The main method in the class is L<find_lanes>, which, given a list of IDs and
their type (lane, sample, etc.), retrieves a list of matching
L<Bio::Path::Find::Lane> objects.

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

Inherits C<config> from L<Bio::Path::Find::Role::HasConfig>.

=attr lane_role

Simple string giving the name of a L<Bio::Path::Find::Lane::Role> that should
be applied to the L<Bio::Path::Find::Lane> objects that we build. The Role is
used to adapt the C<Lane> for use with a particular find command, e.g.
C<pf data> or C<pf assembly>.

=cut

has 'lane_role' => (
  is   => 'ro',
  isa  => Maybe[Str],
);

#---------------------------------------

=attr schema_name

The name of the database schema to be used when searching for tracking data. The
default is C<tracking>, which should correspond to a section in the
C<connection_param> config block:

  <connection_params>
    <tracking>
      driver       SQLite
      dbname       pathogens.db
      schema_class Bio::Track::Schema
    </tracking>
  </connection_params>

If you give a different value for C<schema_name>, make sure there is a
corresponding section in the config.

=cut

has 'schema_name' => (
  is      => 'ro',
  isa     => Str,
  default => 'tracking',
);

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

has '_db_manager' => (
  is      => 'ro',
  isa     => 'Bio::Path::Find::DatabaseManager',
  lazy    => 1,
  builder => '_build_db_manager',
);

sub _build_db_manager {
  my $self = shift;
  return Bio::Path::Find::DatabaseManager->new(
    config      => $self->config,
    schema_name => $self->schema_name,
  );
}

#---------------------------------------

has '_sorter' => (
  is      => 'rw',
  isa     => BioPathFindSorter,
  lazy    => 1,
  default => sub {
    my $self = shift;
    Bio::Path::Find::Sorter->new( config => $self->config );
  },
);

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 find_lanes( ids => ArrayRef[Str], type => IDType, ?qc => QCState, ?filetype => FileType )

Finds lanes using the specified ID(s) (C<ids>) and entity type (C<type>). If
the optional C<qc> attribute is given, only lanes with the specified QC status
will be returned. If the optional C<filetype> is given, the method returns only
lanes having files of the specified type.

=cut

sub find_lanes {
  state $check = compile(
    Object,
    slurpy Dict [
      ids      => ArrayRef[Str],
      type     => IDType,
      qc       => Optional[QCState],
      filetype => Optional[FileType],
    ],
  );
  my ( $self, $params ) = $check->(@_);

  $self->log->debug( 'searching with ' . scalar @{ $params->{ids} }
                     . ' IDs of type "' . $params->{type} . q(") );

  # get a list of Bio::Path::Find::Lane objects
  my $lanes = $self->_find_lanes( $params->{ids}, $params->{type} );

  $self->log->debug('found ' . scalar @$lanes . ' lanes');

  # find files for the lanes and filter based on the files and the QC status
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
    else {
      # we don't care about files; return all lanes
      push @$filtered_lanes, $lane;
    }
  }

  # at this point we have a list of Bio::Path::Find::Lane objects, each of
  # which has a QC status matching the supplied QC value. Each lane has also
  # gone off to look for the files associated with its row in the database

  # sort the lanes based on lane name, etc.
  my $sorted_lanes = $self->_sorter->sort_lanes($filtered_lanes);

  return $sorted_lanes; # array of lane objects
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# actually queries the database(s) to get lane data for the specified ID(s)

sub _find_lanes {
  my ( $self, $ids, $type ) = @_;

  my @db_names = $self->_db_manager->database_names;

  # set up the progress bar
  my $max = scalar( @db_names ) * scalar( @$ids );
  my $pb = $self->_build_pb('finding lanes', $max);

  # walk over the list of available databases and, for each ID, search for
  # lanes matching the specified ID
  my @lanes;
  DB: foreach my $db_name ( @db_names ) {
    $self->log->debug(qq(searching "$db_name"));

    my $database = $self->_db_manager->get_database($db_name);

    ID: foreach my $id ( @$ids ) {
      $self->log->debug( qq(looking for ID "$id") );

      my $rs = $database->schema->get_lanes_by_id($id, $type);
      next ID unless $rs; # no matching lanes

      $self->log->debug('found ' . $rs->count . ' lanes');

      while ( my $lane_row = $rs->next ) {

        # tell every result (a Bio::Track::Schema::Result object) which
        # database it comes from. We need this later to generate paths on disk
        # for the files associated with each result
        $lane_row->database($database);

        # build a lightweight object to hold all of the data about a particular
        # row
        my $lane;

        # if we have the name of a Role to apply, try to do that. Otherwise just
        # hand back the bare Lane, with no Roles applied
        if ( $self->lane_role ) {
          try {
            $lane = Bio::Path::Find::Lane->with_traits( $self->lane_role )
                                         ->new( row => $lane_row );
          } catch {
            Bio::Path::Find::Exception->throw(
              msg => q(ERROR: couldn't apply role ") . $self->lane_role . qq(" to lanes: $_)
            );
          };
        }
        else {
          $lane = Bio::Path::Find::Lane->new( row => $lane_row );
        }

        push @lanes, $lane;
      }

      $pb++;
    }

  }

  return \@lanes;
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

