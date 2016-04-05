
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
  ClassName
);

use Bio::Path::Find::Types qw( :types );

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
    config => \%config_hash
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
      pass   pathpass
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

=attr lane_class

Simple string giving the name of the class of lane objects that we should
return. The default value, L<Bio::Path::Find::Lane>, is the bare lane class.
Any class specified in this attribute should be one that is adapted for use
with a specific find command, such as C<pf data> or C<pf assembly>.

=cut

has 'lane_class' => (
  is      => 'ro',
  isa     => ClassName,
  default => 'Bio::Path::Find::Lane',
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
    # config      => $self->config,
    schema_name => $self->schema_name,
  );
}

#---------------------------------------

has '_sorter' => (
  is      => 'rw',
  isa     => BioPathFindSorter,
  lazy    => 1,
  builder => '_build_sorter',
);

sub _build_sorter {
  Bio::Path::Find::Sorter->new;
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 find_lanes( ids => ArrayRef[Str], type => IDType, ?qc => QCState, ?filetype => FileType, ?lane_attributes => HashRef )

Finds lanes using the specified ID(s) (C<ids>) and entity type (C<type>).

If the optional C<qc> argument is given, only lanes with the specified QC
status will be returned.

If the optional C<filetype> is given, the method returns only lanes having
files of the specified type.

The C<lane_attributes> option can be used to pass in a reference to a hash that
supples a set of attributes (key) and values (value) that should be set on
every C<Lane|Bio::Path::Find::Lane> object as it is created. This is used, for
example, by the L<Bio::Path::Find::App::PathFind::Assembly> command to pass in
a list of assemblers, so that the results of running C<pf assembly> will be
restricted to that list of assemblers.

B<Note> that we do no validation of the attributes list. If you pass in an
attribute name that's not supported by the C<Lane> class, you'll get an ugly
Moose error for your troubles.

=cut

sub find_lanes {
  state $check = compile(
    Object,
    slurpy Dict [
      ids             => ArrayRef[Str],
      type            => IDType,
      processed       => Optional[ProcessedFlag],
      qc              => Optional[QCState],
      filetype        => Optional[FileType],
      lane_attributes => Optional[HashRef],
      subdirs         => Optional[ArrayRef[PathClassDir]],
    ],
  );
  my ( $self, $params ) = $check->(@_);

  $self->log->debug( 'searching with ' . scalar @{ $params->{ids} }
                     . ' IDs of type "' . $params->{type} . q(") );

  # get a list of Bio::Path::Find::Lane objects
  my $finder_params = [
    $params->{ids},
    $params->{type},
    $params->{processed},         # filter
    $params->{qc},                # filter
    $params->{lane_attributes},
  ];

  my $lanes = $params->{type} eq 'database'
            ? $self->_find_all_lanes(@$finder_params)
            : $self->_find_lanes(@$finder_params);

  my $max = scalar @$lanes;
  $self->log->debug("found $max lanes");

  # show a progress bar if we've got more than 50 lanes
  my $pb = $max > 50
         ? $self->_create_pb('finding files', $max)
         : 0;

  # find files for the lanes and filter based on the files and the QC status
  my $filtered_lanes = [];
  LANE: foreach my $lane ( @$lanes ) {

    # return lanes that have a specific type of file
    if ( $params->{filetype} ) {

      $lane->find_files( $params->{filetype}, $params->{subdirs} );

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

    $pb++;

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

# return all lanes for a specific database

sub _find_all_lanes {
  my ( $self, $ids, $type, $processed, $qc, $lane_attributes ) = @_;

  return unless ( defined $ids and scalar @$ids == 1 );
  return unless ( defined $type and $type eq 'database' );

  my $dbname = $ids->[0];

  # check DB actually exists
  my $database = $self->_db_manager->get_database($dbname);
  unless ( defined $database ) {
    say STDERR qq|No such database ("$dbname")|;
    return;
  }

  # get all lanes... This step is a cheap operation, because DBIC doesn't do a
  # database query until we actually try to read something from the ResultSet
  my $rs = $database->schema->get_all_lanes;

  my $num_rows = $rs->count;

  # check for explicit authorisation before doing something this dumb
  unless ( $ENV{PF_ENABLE_DB_DUMP} ) {
    # throw an exception about what a dumb idea this is
    Bio::Path::Find::Exception->throw(
      msg => <<"EOF_bad_idea"
WARNING: you are about to retrieve $num_rows lanes from the database; that
         could be a *very* bad thing to do. If you're sure you know what
         you're doing, set the environment variable PF_ENABLE_DB_DUMP to 1
         and try again.
EOF_bad_idea
    );
  }

  # OK. The user *really* wants to do this...

  my $pb = $self->_create_pb('finding lanes', $rs->count);

  my @lanes;
  while ( my $lane_row = $rs->next ) {
    $pb++;

    # build the Lane object, subject to any filters
    my $lane = $self->_create_lane(
      $lane_row,
      $processed,
      $qc,
      $lane_attributes
    );

    next unless defined $lane;

    # tell every result (a Bio::Track::Schema::Result object) which
    # database it comes from. We need this later to generate paths on disk
    # for the files associated with each result
    $lane->row->database($database);

    push @lanes, $lane if defined $lane;

  }

  return \@lanes;
}

#-------------------------------------------------------------------------------

# query the databases to find lane data for the specified ID(s)

sub _find_lanes {
  my ( $self, $ids, $type, $processed, $qc, $lane_attributes ) = @_;

  my @db_names = $self->_db_manager->database_names;

  # set up the progress bar
  my $max = scalar( @db_names ) * scalar( @$ids );
  my $pb = $self->_create_pb('finding lanes', $max);

  # walk over the list of available databases and, for each ID, search for
  # lanes matching the specified ID
  my @lanes;
  DB: foreach my $db_name ( @db_names ) {
    $self->log->debug(qq(searching "$db_name"));

    my $database = $self->_db_manager->get_database($db_name);

    ID: foreach my $id ( @$ids ) {
      $self->log->debug( qq(looking for ID "$id") );

      my $rs = $database->schema->get_lanes_by_id($id, $type, $processed);

      next ID unless $rs; # no matching lanes

      $self->log->debug('found ' . $rs->count . ' lanes');

      ROW: while ( my $lane_row = $rs->next ) {

        # build the Lane object, subject to any filters
        my $lane = $self->_create_lane(
          $lane_row,
          $processed,
          $qc,
          $lane_attributes
        );

        next unless defined $lane;

        # tell every result (a Bio::Track::Schema::Result object) which
        # database it comes from. We need this later to generate paths on disk
        # for the files associated with each result
        $lane->row->database($database);

        push @lanes, $lane if defined $lane;
      }

      $pb++;
    }

  }

  return \@lanes;
}

#-------------------------------------------------------------------------------

# given a row from the database and some filters, try to create a Lane object

sub _create_lane {
  my ( $self, $lane_row, $processed, $qc, $lane_attributes ) = @_;

  # apply any filters

  # if we have a value for "processed", use it as a bit mask and see if
  # this lane has the specified bit set
  return if ( defined $processed and ( $lane_row->processed & $processed ) == 0 );

  # (there's a mechanism for filtering on "processed" in the
  # Bio::Track::Schema code, but it has to walk through the resultset and
  # check each lane in turn.  We're doing that anyway here, so it's more
  # efficient to check for the processed flag in this code than in the
  # schema.)

  # ignore this lane if:
  #   1. we've been told to look for a specific QC status, and
  #   2. the lane has a QC status set, and
  #   3. this lane's QC status doesn't match the required status
  if ( defined $qc and
       defined $lane_row->qc_status and
       $lane_row->qc_status ne $qc ) {
    $self->log->debug(
      'lane "' . $lane_row->name
      . '" filtered by QC status (actual status is "' . $lane_row->qc_status
      . qq|'"; requiring status "$qc")|
    );
    return;
  }

  # build a lightweight object to hold all of the data about a particular
  # row
  my $lane;

  try {
    # return the type of class that's specified by the "lane_class"
    # attribute. Set attributes on the lanes at instantiation
    $lane = $self->lane_class->new( row => $lane_row, %$lane_attributes );
  } catch {
    Bio::Path::Find::Exception->throw(
      msg => q(ERROR: couldn't build lane class ") . $self->lane_class . qq(": $_)
    );
  };

  return $lane;
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

