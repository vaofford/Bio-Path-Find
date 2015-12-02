
package Bio::Path::Find::App::PathFind;

# ABSTRACT: the guts of a pathfind app

use v5.10; # for "say"

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw( carp croak );
use Archive::Tar;
use Path::Class;

use Types::Standard qw(
  ArrayRef
  Str
  +Bool
);

use Bio::Path::Find::Types qw(
  FileType
  QCState
  +PathClassDir  DirFromStr
  +PathClassFile FileFromStr
);

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
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

has 'filetype' => (
  documentation => 'file type to find; fastq | bam | pacbio | corrected',
  is            => 'rw',
  isa           => FileType,
  cmd_aliases   => 'f',
  traits        => ['Getopt'],
);

has 'qc' => (
  documentation => 'QC state; passed | failed | pending',
  is            => 'rw',
  isa           => QCState,
  cmd_aliases   => 'q',
  traits        => ['Getopt'],
);

# TODO implement these

has 'symlink' => (
  documentation => 'create symlinks for data files in the specified directory',
  is            => 'rw',
  isa           => PathClassDir->plus_coercions(DirFromStr), # (coerce from strings to Path::Class::Dir objects)
  cmd_aliases   => 'l',
  traits        => ['Getopt'],
  trigger       => sub {
    my ( $self, $new_dir, $old_dir ) = @_;
    # throw an exception unless the specified directory is sensible
    croak 'ERROR: no such directory, ' . $new_dir unless -d $new_dir;
  },
);
has 'stats' => (
  documentation => 'filename for statistics output',
  is            => 'rw',
  isa           => Str,
  cmd_aliases   => 's',
  traits        => ['Getopt'],
);

has 'rename' => (
  documentation => 'replace hash (#) with underscore (_) in filenames',
  is            => 'rw',
  isa           => Bool,
  cmd_aliases   => 'r',
  traits        => ['Getopt'],
);

has 'archive' => (
  documentation => 'filename for archive',
  is            => 'rw',
  isa           => Str|Bool,
  cmd_aliases   => 'a',
  traits        => ['Getopt'],
);

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 run

Find files according to the input parameters.

=cut

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
    foreach my $lane ( @$lanes ) {
      $lane->make_symlinks( dest => $self->symlink, rename => $self->rename );
    }
  }
  elsif ( $self->archive ) {
    $self->_make_archive($lanes);
  }
  else {
    $_->print_paths for ( @$lanes );
  }

}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

sub _make_archive {
  my ( $self, $lanes ) = @_;

  my $tar_filename;

  # this is used in the filename and as a folder name within the archive
  ( my $id = $self->id ) =~ s/\#/_/g;

  # decide on the name of the tar archive
  if ( not is_Bool($self->archive) ) {
    $self->log->debug('archive attribute is a PathClassFile; using it as a filename');
    $tar_filename = $self->archive;
  }
  else {
    $self->log->debug('archive attribute is a boolean; building a filename');
    # we'll ALWAYS make a sensible name for the archive itself
    $tar_filename = "pathfind_$id.tar.gz";
  }

  say "Archiving lanes to '$tar_filename'";

  my $tar = Archive::Tar->new;

  my @filenames;
  foreach my $lane ( @$lanes ) {
    # if the Finder was set up to look for a specific filetype, we don't need
    # to do a find here. If it was not given a filetype, it won't have looked
    # for data files, just the directory for the lane, so we need to find data
    # files here explicitly
    $lane->find_files('fastq') if not $self->filetype;

    foreach my $filename ( $lane->all_files ) {
      say "adding $filename";
      push @filenames, $filename;
    }
  }

  $tar->add_files(@filenames);

  # the files are added with their full paths. We want them to be relative,
  # so we'll go through the archive and rename them all. If the "-rename"
  # option is specified, we'll also rename the individual files to convert
  # hashes to underscores
  foreach my $old_filename ( @filenames ) {

    my $new_basename = $old_filename->basename;

    # honour the "-rename" option
    $new_basename =~ s/\#/_/g if $self->rename;

    # add on the folder to get the relative path for the file in the
    # archive
    my $new_filename = file( $id, $new_basename );

    # filenames in an archive are specified as Unix paths (see
    # https://metacpan.org/pod/Archive::Tar#tar-rename-file-new_name)
    $old_filename = file( $old_filename )->as_foreign('Unix');
    $new_filename = file( $new_filename )->as_foreign('Unix');

    $self->log->debug( "renaming |$old_filename| to |$new_filename|" );

    $tar->rename( $old_filename, $new_filename )
      or carp "WARNING: couldn't rename '$old_filename' in archive";
  }

  $tar->write( $tar_filename, COMPRESS_GZIP );
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

