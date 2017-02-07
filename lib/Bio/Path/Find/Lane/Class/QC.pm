
package Bio::Path::Find::Lane::Class::QC;

# ABSTRACT: a class that adds QC-find-specific functionality to the B::P::F::Lane class

use Moose;
use Path::Class;
use Bio::Path::Find::Types qw( :all );

extends 'Bio::Path::Find::Lane';

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

# make the "filetype" attribute require values of type QCType, which is
# actually only "kraken". This is to make sure that this class correctly
# restricts the sorts of files that it will return.

has '+filetype' => (
  isa => QCType,
);

#-------------------------------------------------------------------------------
#- builders for file finding ---------------------------------------------------
#-------------------------------------------------------------------------------

# this sets the mapping between filetype and patterns matching filenames on
# disk. It's potentially used by B::P::F::Lane objects to find files when no
# filetype is specified but, in fact, the mechanism for finding assemblies is
# actually set up to use the three "_get_*" methods below, so the mapping is
# redundant. It's only here for consistency.
#
# this mapping is taken from the original assemblyfind
# (PathFind/lib/Path/Find/CommandLine/Assembly.pm:193)

sub _build_filetype_extensions {
  return {
    kraken => 'kraken.report',
  };
}

#-------------------------------------------------------------------------------

# given a "from" and "to" filename, edit the destination to change the format
# of the filename. This gives this Lane a chance to edit the filenames that are
# used, so that they can be specialised to assembly data.
#
# For example, this method is called by B::P::F::Role::Linker before it creates
# links. This method makes the link destination look like:
#
#   <dst_path directory> / <id>_kraken.report
#
#  e.g. 11657_5#33/11657_5#33_kraken.report

sub _edit_filenames {
  my ( $self, $src_path, $dst_path ) = @_;

  my @src_path_components = $src_path->components;

  my $id_dir      = $src_path_components[-2];
  my $filename    = $src_path_components[-1];

  my $new_dst = file( $dst_path->dir, $id_dir . '_' . $filename );

  return ( $src_path, $new_dst );
}


1;

