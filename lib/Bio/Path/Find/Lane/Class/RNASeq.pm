
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

# build mapping between filetype and file extension. The mapping is specific
# to data files related to lanes, such as fastq or bam.

sub _build_filetype_extensions {
  {
    coverage      => '*coverageplot.gz',
    intergenic    => '*tab.gz',
    bam           => '*corrected.bam',
    spreadsheet   => '*expression.csv',
    featurecounts => '*featurecounts.csv',
  };
}

# NOTE if there is a "_get_*" method for one of the keys, then calling
# NOTE $lane->find_files(filetype=>'<key>') will call that method to find files.
# NOTE If there's no corresponding "_get_*" method, "find_files" will fall back
# NOTE on calling "_get_files_by_extension", which will use Find::File::Rule to
# NOTE look for files according to the pattern given in the hash value.

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# given a "from" and "to" filename, edit the destination to change the format
# of the filename. This gives this Lane a chance to edit the filenames that are
# used, so that they can be specialised to assembly data.
#
# For example, this method is called by B::P::F::Role::Linker before it creates
# links. This method makes the link destination look like:
#
#   <dst_path directory> / <id>.<mapstats_id>.mpileup.unfilt.vcf.gz
#
#  e.g. 11657_5#33/11657_5#33.851642.mpileup.unfilt.vcf.gz
#       11657_5#33/11657_5#33.851642.mpileup.unfilt.vcf.gz.tbi

# sub _edit_filenames {
#   my ( $self, $src_path, $dst_path ) = @_;
#
#   my @src_path_components = $src_path->components;
#
#   my $id_dir      = $src_path_components[-3];
#   my $mapping_dir = $src_path_components[-2];
#   my $filename    = $src_path_components[-1];
#
#   ( my $mapstats_id = $mapping_dir ) =~ s/^(\d+)\..*$/$1/;
#
#   my $new_dst = file( $dst_path->dir, $id_dir . '.' . $mapstats_id . '_' . $filename );
#
#   return ( $src_path, $new_dst );
# }

#-------------------------------------------------------------------------------

1;

