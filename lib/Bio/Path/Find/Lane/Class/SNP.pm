
package Bio::Path::Find::Lane::Class::SNP;

# ABSTRACT: a class that adds SNP-finding functionality to the B::P::F::Lane class

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

# make the "filetype" attribute require values of type SNPType. This is to make
# sure that this class correctly restrict the sorts of files that it will
# return.

has '+filetype' => (
  isa => Maybe[SNPType],
);

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

sub _edit_filenames {
  my ( $self, $src_path, $dst_path ) = @_;

  my @src_path_components = $src_path->components;

  my $id_dir      = $src_path_components[-3];
  my $mapping_dir = $src_path_components[-2];
  my $filename    = $src_path_components[-1];

  ( my $mapstats_id = $mapping_dir ) =~ s/^(\d+)\..*$/$1/;

  my $new_dst = file( $dst_path->dir, $id_dir . '.' . $mapstats_id . '_' . $filename );

  return ( $src_path, $new_dst );
}

#-------------------------------------------------------------------------------

# find files for the lane. This is a call to a method on the "HasMapping" Role.
# That method takes care of finding the mapstats IDs for the lane, then turns
# around and calls "_generate_filenames" back here.

sub _get_vcf {
  return shift->_get_mapping_files('vcf', 'tbi');
}

#---------------------------------------

sub _get_pseudogenome {
  return shift->_get_mapping_files('pseudogenome');
}

#-------------------------------------------------------------------------------

# called from the "_get_mapping_files" method on the HasMapping Role, this method
# handles the specifics of finding VCF and index files for this lane


sub _generate_filenames_generic {
  my ( $self, $mapstats_id, $pairing, $filetype, $index_suffix, $stage ) = @_;

  my $mapping_dir = "$mapstats_id.$pairing.$stage.snp";
  my $file = $filetype eq 'vcf'
           ? 'mpileup.unfilt.vcf.gz'
           : 'pseudo_genome.fasta';

  my @returned_files;

  if ( -f file($self->storage_path, $mapping_dir, $file) ) {
    push @returned_files, file($self->symlink_path, $mapping_dir, $file);
  }
  elsif (-f file($self->symlink_path, $mapping_dir, $file)) 
  {
    # Either the path isnt stored or the stored link is incorrect so fall back to the full path
    push @returned_files, file($self->symlink_path, $mapping_dir, $file);
  }

  if ( $index_suffix ) {
    if ( -f file($self->storage_path, $mapping_dir, "$file.$index_suffix") ) {
      push @returned_files, file($self->symlink_path, $mapping_dir, "$file.$index_suffix");
    }
    elsif( -f file($self->symlink_path, $mapping_dir, "$file.$index_suffix"))
    {
    	push @returned_files, file($self->symlink_path, $mapping_dir, "$file.$index_suffix");
    }
  }

  return \@returned_files;
}


sub _generate_filenames {
  my ( $self, $mapstats_id, $pairing, $filetype, $index_suffix ) = @_;

  my $returned_files = $self->_generate_filenames_generic($mapstats_id, $pairing, $filetype, $index_suffix,'markdup' );
  
  if(@{$returned_files} == 0)
  {
      $self->_generate_filenames_generic($mapstats_id, $pairing, $filetype, $index_suffix,'raw.sorted' );
  }
  else
  {
	  
	  my $file = $filetype eq 'vcf'
	           ? 'mpileup.unfilt.vcf.gz'
	           : 'pseudo_genome.fasta';
      say STDERR qq(WARNING: couldn't find file "$mapstats_id.$pairing.(markdup|raw.sorted).snp/$file"; mapping $mapstats_id may not be finished?);
  }
  return $returned_files;
}

#-------------------------------------------------------------------------------

1;

