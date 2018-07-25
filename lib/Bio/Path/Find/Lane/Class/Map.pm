
package Bio::Path::Find::Lane::Class::Map;

# ABSTRACT: a class that adds mapping-specific functionality to the B::P::F::Lane class

use v5.10; # for "say"

use Moose;
use Path::Class;
use Carp qw( carp );

use Types::Standard qw(
  Maybe
  Str
  HashRef
  ArrayRef
);

use Bio::Path::Find::Types qw( :all );

extends 'Bio::Path::Find::Lane';

with 'Bio::Path::Find::Lane::Role::HasMapping';

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

# make the "filetype" attribute require values of type MapType. This is to make
# sure that this class correctly restrict the sorts of files that it will
# return.

has '+filetype' => (
  isa => Maybe[MapType],
);

#-------------------------------------------------------------------------------
#- builders --------------------------------------------------------------------
#-------------------------------------------------------------------------------

# this sets the mapping between filetype and patterns matching filenames on
# disk. In this case the value is not needed, because the finding mechanism
# calls "_get_bam", so we never fall back on the general "_get_extensions"
# method.

sub _build_filetype_extensions {
  return {
    bam => 'markdup.bam',
  };
}

# (if there is a "_get_*" method for one of the keys, then calling
# $lane->find_files(filetype=>'<key>') will call that method to find files.  If
# there's no corresponding "_get_*" method, "find_files" will fall back on
# calling "_get_files_by_extension", which will use Find::File::Rule to look
# for files according to the pattern given in the hash value.)

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# find files for the lane. This is a call to a method on the "HasMapping" Role.
# That method takes care of finding the mapstats IDs for the lane, then turns
# around and calls "_generate_filenames" back here.

sub _get_bam {
  return shift->_get_mapping_files('bam','bai');
  # NOTE that the filetype argument isn't really necessary, because the
  # "_generate_filenames" method will only return bam files
}

#-------------------------------------------------------------------------------

# called from the "_get_mapping_files" method on the HasMapping Role, this
# method handles the specifics of finding bam files for this lane. It returns a
# list of files that its found for this lane.

sub _generate_filenames {
  my ( $self, $mapstats_id, $pairing, $filetype, $index_suffix ) = @_;

  my $markdup_file = "$mapstats_id.$pairing.markdup.bam";
  my $raw_file     = "$mapstats_id.$pairing.raw.sorted.bam";

  my @returned_files;
  my $returned_file;
  if ( -f file($self->storage_path, $markdup_file) ) {
    # if the markdup file exists, we show that. Note that we check that the
    # file exists using the storage path (on NFS), but return the symlink
    # path (on lustre)
    $returned_file = $markdup_file;
  }
  elsif(-f file( $self->symlink_path, $markdup_file) )
  {
     $returned_file = $markdup_file;
  }
  else {
    # if the markdup file *doesn't* exist, we fall back on the
    # ".raw.sorted.bam" file, which should always exist. If it doesn't exist
    # (check on the NFS filesystem), issue a warning, but return the path to
    # file anyway
    $returned_file = $raw_file;

    carp qq(WARNING: expected to find raw bam file at "$returned_file", but it was missing)
      unless -f file($self->symlink_path, $raw_file);
  }
  push  @returned_files, file( $self->symlink_path, $returned_file);
  
  if ( $index_suffix ) {
    if ( -f file($self->storage_path, "$returned_file.$index_suffix") ) {
      push @returned_files, file( $self->symlink_path, "$returned_file.$index_suffix");
    }
    elsif( -f file($self->symlink_path, "$returned_file.$index_suffix"))
    {
      push @returned_files, file( $self->symlink_path, "$returned_file.$index_suffix");
    }
  }
  
  return \@returned_files;
}

#-------------------------------------------------------------------------------

1;

