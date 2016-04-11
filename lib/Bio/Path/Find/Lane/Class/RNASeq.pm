
package Bio::Path::Find::Lane::Class::RNASeq;

# ABSTRACT: a class that handles RNA-Seq-related data

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

# make the "filetype" attribute require values of type RNASeqType. This is to
# make sure that this class correctly restrict the sorts of files that it will
# return.

has '+filetype' => (
  isa => Maybe[RNASeqType],
);

#-------------------------------------------------------------------------------
#- builders --------------------------------------------------------------------
#-------------------------------------------------------------------------------

# build mapping between filetype and file extension. The mapping is specific
# to data files related to lanes, such as fastq or bam.

sub _build_filetype_extensions {
  {
    bam           => '*corrected.bam',
    coverage      => '*coverageplot.gz',
    featurecounts => '*featurecounts.csv',
    intergenic    => '*tab.gz',
    spreadsheet   => '*expression.csv',
  };
}

#---------------------------------------

# when file-finding, don't fall back on the "_get_files_by_extension"
# mechanism, otherwise we end up bypassing the "mapper" and "extension"
# filters

sub _build_skip_extension_fallback { 1 }

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# The file-finding code in this Lane class uses a hybrid of the approaches in
# the others Lane classes.
#
# We need to be able to filter lanes on mapper and reference, so we have a
# method for each of the filetypes that we support, and those methods call the
# "_get_mapping_files" method from the "HasMapping" role. "_get_mapping_files"
# calls "_generate_filenames" back in here, and THAT method turns around and
# calls "_get_files_by_extension", which uses the extension-to-regex mapping
# set up by "build_filetype_extensions" above.

sub _get_bam           { shift->_get_mapping_files('bam') }
sub _get_coverage      { shift->_get_mapping_files('coverage') }
sub _get_featurecounts { shift->_get_mapping_files('featurecounts') }
sub _get_intergenic    { shift->_get_mapping_files('intergenic') }
sub _get_spreadsheet   { shift->_get_mapping_files('spreadsheet') }

#-------------------------------------------------------------------------------

# called from the "_get_mapping_files" method on the HasMapping Role, this
# method handles the specifics of finding files for this lane

sub _generate_filenames {
  my ( $self, $mapstats_id, $pairing, $filetype, $index_suffix ) = @_;

  my $extension = $self->filetype_extensions->{$filetype};

  # Should Never Happen (tm). The extension should *always* be found in the
  # list of extensions, otherwise $filetype would have hit a Moose type
  # validation exception when it was set. This is true as long as the list of
  # extensions in "_build_filetype_extensions" is in sync with the list in the
  # enum in B::P::F::Types.
  return unless defined $extension;

  my $files = $self->_get_files_by_extension($extension);

  return $files;
}

#-------------------------------------------------------------------------------

# given a "from" and "to" filename, edit the destination to change the format
# of the filename. This gives this Lane a chance to edit the filenames that are
# used, so that they can be specialised to assembly data.
#
# For example, this method is called by B::P::F::Role::Linker before it creates
# links. This method makes the link destination look like:
#
#   <dst_path directory> / <id>.<mapstats_id>.pe.markdup.bam.expression.csv
#
#  e.g. 11657_5#33/11657_5#33.851642.pe.markdup.bam.expression.csv

sub _edit_filenames {
  my ( $self, $src_path, $dst_path ) = @_;

  my @src_path_components = $src_path->components;

  my $id_dir      = $src_path_components[-2];
  my $filename    = $src_path_components[-1];

  my $new_dst = file( $dst_path->dir, $id_dir . '.' . $filename );

  return ( $src_path, $new_dst );
}

#-------------------------------------------------------------------------------

1;

