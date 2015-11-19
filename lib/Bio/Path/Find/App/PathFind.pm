
package Bio::Path::Find::App::PathFind;

# ABSTRACT: the guts of a pathfind app

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw( croak );

with 'Bio::Path::Find::App::Role::AppRole';

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

sub run {
  my $self = shift;

  # log the command line to file
  $self->_log_command;

  # check for dependencies between parameters: if "type" is "file", we need to
  # know what type of IDs we'll find in the file
  croak q(ERROR: if "type" is "file", you must also specify "file_id_type")
    if ( $self->type eq 'file' and not $self->file_id_type );

  #---------------------------------------

  # we can't use "type" to tell us what kind of IDs we're working with, since
  # it can be set to "file", in which case we need to look at "file_id_type"
  # to get the type of IDs in the file...

  my ( $ids, $type ) = $self->_tidy_id_and_type;

  #---------------------------------------

  # find lanes

  # build the parameters for the finder. Omit undefined options, or Moose spits
  # the dummy
  my %finder_params = (
    ids  => $ids,
    type => $type,
  );
  $finder_params{qc}       = $self->qc       if defined $self->qc;
  $finder_params{filetype} = $self->filetype if defined $self->filetype;

  my $lanes = $self->_finder->find_lanes(%finder_params);

  #---------------------------------------

  $self->log->debug( 'found ' . scalar @$lanes . ' lanes' );

  if ( $self->symlink ) {
    $self->_find->symlink( $lanes, $self->symlink );
  }
  else {
    $self->_find->print_paths( $lanes );
  }

  # TODO handle archiving
}
#-------------------------------------------------------------------------------

1;



# TODO just started refactoring to get rid of Bio::Path::Find and move
# TODO functionality into here. Finish off that tidying up and fix AppRole
# TODO and update tests
