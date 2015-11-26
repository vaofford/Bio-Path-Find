
package Bio::Path::Find::App::PathFind;

# ABSTRACT: the guts of a pathfind app

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw( croak );

# the boilerplate functionality for this class comes from the AppRole
with 'Bio::Path::Find::App::Role::AppRole',
     'MooseX::Log::Log4perl';

=head1 DESCRIPTION

  Find information about sequencing files.

  Required:
    -i,  --id        ID to find, or name of file containing IDs to find
    -t,  --type      type of ID(s); lane|sample|library|study|species|file

  Required if type is "file":
    -ft, --file_id_type
                     type of IDs in file input file; lane|sample

  Optional:
    -ft, --filetype  type of file to return; fastq|bam|pacbio|corrected
    -q,  --qc        filter on QC status; passed|failed|pending
    -s,  --stats <output file>
                     create a file containing statistics for found data
    -l,  --symlink <destination directory>
                     create symbolic links to data files in the destination dir
    -a,  --archive <tar file>
                     create an archive of data files
    -r,  --rename    convert hash (#) to underscore (_) in output filenames
    -h,  -?          print this message

=cut

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

sub run {
  my $self = shift;

  # log the command line to file
  $self->_log_command;

  # set up the finder

  # build the parameters for the finder. Omit undefined options or Moose spits
  # the dummy
  my %finder_params = (
    ids  => $self->_ids,
    type => $self->_type,
  );
  $finder_params{qc}       = $self->qc       if defined $self->qc;
  $finder_params{filetype} = $self->filetype if defined $self->filetype;

  # find lanes
  my $lanes = $self->_finder->find_lanes(%finder_params);

  #---------------------------------------

  $self->log->debug( 'found ' . scalar @$lanes . ' lanes' );

  if ( $self->symlink ) {
    $_->symlink($self->symlink) for ( @$lanes );
  }
  else {
    $_->print_paths for ( @$lanes );
  }

  # TODO implement symlinking
  # TODO handle archiving
}

#-------------------------------------------------------------------------------

1;

