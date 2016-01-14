
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

use Term::ProgressBar::Simple;

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

with 'Bio::Path::Find::Role::HasConfig',
     'MooseX::Log::Log4perl';

=head1 CONTACT

path-help@sanger.ac.uk

=cut

# defaults for the mapping between a script name and a Role to apply to the
# Lane objects that we return

our $lane_roles = {
  pf       => 'Bio::Path::Find::Lane::Role::PathFind',
  pathfind => 'Bio::Path::Find::Lane::Role::PathFind',
};

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

Inherits C<config> from L<Bio::Path::Find::Role::HasConfig>.

=attr lane_role

Simple string giving the name of a L<Bio::Path::Find::Role> that should be
applied to the L<Bio::Path::Find::Lane> objects that we build. The Role is used
to adapt the C<Lane> for use with a particular "*find" script, e.g. C<pathfind>
or C<annotationfind>.

If C<lane_role> is not supplied, we try to look up a mapping between script
name and Role name in the config, for example:

 <lane_roles>
   pathfind       Bio::Path::Find::Lane::Role::PathFind
   infofind       Bio::Path::Find::Lane::Role::InfoFind
   accessionfind  Bio::Path::Find::Lane::Role::AccessionFind
 </lane_roles>

If the config doesn't contain a C<lane_roles> mapping, we use the default,
hard-coded mapping in this class:

 our $lane_roles = {
   pathfind      => 'Bio::Path::Find::Lane::Role::PathFind',
   infofind      => 'Bio::Path::Find::Lane::Role::InfoFind',
   accessionfind => 'Bio::Path::Find::Lane::Role::AccessionFind',
 };

Finally, if, at the end of that, we can't find the name of a Role to apply, the
value of C<lane_role> is left as C<undef>, and later on when we find lanes,
 simply won't have a Role applied to them before being returned.

=cut

has 'lane_role' => (
  is      => 'ro',
  isa     => Maybe[Str],
  lazy    => 1,
  builder => '_build_lane_role',
);

# TODO this mechanism for picking lane roles won't work now that we've switched
# TODO to a git-style app. Need to find a better way to determine which Role
# TODO should be applied to Lane objects

sub _build_lane_role {
  my $self = shift;

  my $role;
  if ( exists $self->config->{lane_roles} and
       exists $self->config->{lane_roles}->{ $self->_script_name } ) {
    $self->log->debug('found lane role using script name in mapping from config');
    $role = $self->config->{lane_roles}->{ $self->_script_name };
  }
  elsif ( exists $lane_roles->{ $self->_script_name } ) {
    $self->log->debug('found lane role using script name in mapping from class');
    $role = $lane_roles->{ $self->_script_name };
  }
  else {
    $self->log->debug( "couldn't find a lane role for this script ("
                       . $self->_script_name . ') in config or class mapping' );
  }

  return $role;
}

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

# normally this just returns the real name of the script, but it's intended to
# allow the script name to be explicitly set in a test, so that the lane_role
# builder can be exercised.

has '_script_name' => (
  is      => 'ro',
  isa     => Str,
  default => sub { basename $0 },
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

sub _find_lanes {
  my ( $self, $ids, $type ) = @_;

  my @db_names = $self->_db_manager->database_names;

  # set up the progress bar
  my $max = scalar( @db_names ) * scalar( @$ids );
  my $pb = $self->config->{no_progress_bars}
         ? 0
         : Term::ProgressBar::Simple->new( {
             name   => 'finding lanes',
             count  => $max,
             remove => 1,
           } );

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

