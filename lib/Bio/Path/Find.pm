
package Bio::Path::Find;

# ABSTRACT: coordinate the finding and presention of lane data

use v5.10; # required for:
           #   Type::Params' use of "state"
           #   general use of "say"

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw( croak carp );

use Type::Params qw( compile );
use Types::Standard qw(
  ArrayRef
  Str
  Object
  slurpy
  Dict
  Optional
);
use Type::Utils qw( enum );
use Bio::Path::Find::Types qw(
  BioPathFindFinder
  BioPathFindLane
  IDType
  FileIDType
  QCState
  FileType
  PathClassDir
  PathClassFile
);

use Bio::Path::Find::Finder;

with 'Bio::Path::Find::Role::HasConfig',
     'Bio::Path::Find::Role::HasEnvironment',
     'MooseX::Log::Log4perl';

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

has '_finder' => (
  is      => 'ro',
  isa     => BioPathFindFinder,
  lazy    => 1,
  builder => '_build_finder',
);

sub _build_finder {
  my $self = shift;

  return Bio::Path::Find::Finder->new(
    config      => $self->config,
    environment => $self->environment,
  );
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head2 find($params)

Find lanes.

=cut

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
  croak q(ERROR: if "type" is "file", you must also specify "file_id_type")
    if ( $params->{type} eq 'file' and not $params->{file_id_type} );

  #---------------------------------------

  # we can't use "type" to tell us what kind of IDs we're working with, since
  # it can be set to "file", in which case we need to look at "file_id_type"
  # to get the type of IDs in the file...

  my ( $ids, $type );
  if ( $params->{type} eq 'file' ) {
    # read multiple IDs from a file
    $ids  = $self->_load_ids_from_file( file($params->{id}) );
    $type = $params->{file_id_type};

    $self->log->debug('found ' . scalar @$ids . ' IDs from file ' . $params->{id}
                      . qq(, of type "$type") );
  }
  else {
    # use the single ID from the command line
    $ids  = [ $params->{id} ];
    $type = $params->{type};

    $self->log->debug(  q(looking for single ID, ") . $params->{id} .q(")
                      . q(, of type ") . $params->{type} . q(") );
  }

  #---------------------------------------

  # find lanes

  # build the parameters for the finder. Omit undefined options, or Moose spits
  # the dummy
  my %finder_params = (
    ids  => $ids,
    type => $type,
  );
  $finder_params{qc}       = $params->{qc}       if defined $params->{qc};
  $finder_params{filetype} = $params->{filetype} if defined $params->{filetype};

  my $lanes = $self->_finder->find_lanes(%finder_params);

  $self->log->debug( 'found ' . scalar @$lanes . ' lanes' );

  return $lanes;
}

#-------------------------------------------------------------------------------

=head2 print_paths($lanes)

Print paths for supplied lanes.

=cut

sub print_paths {
  state $check = compile( Object, ArrayRef[BioPathFindLane] );
  my ( $self, $lanes ) = $check->(@_);

  say 'Could not find lanes or files for input data' unless scalar @$lanes;

  $_->print_paths for ( @$lanes );
}

#-------------------------------------------------------------------------------

=head2 symlink($dest)

Create symlinks for all found files in the destination directory.

=cut

sub symlink {
  state $check = compile( Object, ArrayRef[BioPathFindLane], PathClassDir );
  my ( $self, $lanes, $destination ) = $check->(@_);

  say 'Could not find lanes or files for input data' unless scalar @$lanes;

  $_->symlink($destination) for ( @$lanes );
}

#-------------------------------------------------------------------------------

=head2 stats

Returns the statistics report for the found lanes.

=cut

sub stats {
  my ( $self, $args ) = @_;

  # TODO fill in this method
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

sub _load_ids_from_file {
  my ( $self, $filename ) = @_;

  croak "ERROR: no such file ($filename)" unless -f $filename;

  # TODO check if this will work with the expected usage. If users are used
  # TODO to putting plex IDs as search terms, stripping lines starting with
  # TODO "#" will break those searches
  my @ids = grep ! m/^#/, $filename->slurp(chomp => 1);

  croak "ERROR: no IDs found in file ($filename)" unless scalar @ids;

  return \@ids;
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

