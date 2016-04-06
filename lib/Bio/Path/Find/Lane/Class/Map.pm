
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

with 'Bio::Path::Find::Lane::Role::Stats',
     'Bio::Path::Find::Lane::Role::HasMapping';

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

#---------------------------------------

# build an array of headers for the statistics report
#
# required by the Stats Role

sub _build_stats_headers {
  return [
    'Study ID',
    'Sample',
    'Lane Name',
    'Cycles',
    'Reads',
    'Bases',
    'Map Type',
    'Reference',
    'Reference Size',
    'Mapper',
    'Mapstats ID',
    'Mapped %',
    'Paired %',
    'Mean Insert Size',
    'Depth of Coverage',
    'Depth of Coverage sd',
    'Genome Covered (% >= 1X)',
    'Genome Covered (% >= 5X)',
    'Genome Covered (% >= 10X)',
    'Genome Covered (% >= 50X)',
    'Genome Covered (% >= 100X)',
  ];
}

#-------------------------------------------------------------------------------

# collect together the fields for the statistics report
#
# required by the Stats Role

sub _build_stats {
  my $self = shift;

  # for each mapstats row for this lane, get a row of statistics, as an
  # arrayref, and push it into the return array.
  my @stats = map { $self->_get_stats_row($_) } $self->_all_mapstats_rows;

  return \@stats;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# find files for the lane. This is a call to a method on the "HasMapping" Role.
# That method takes care of finding the mapstats IDs for the lane, then turns
# around and calls "_generate_filenames" back here. 

sub _get_bam {
  return shift->_get_files('bam');
  # NOTE that the filetype argument isn't really necessary, because the
  # "_generate_filenames" method will only return bam files
}

#-------------------------------------------------------------------------------

# called from the "_get_files" method on the HasMapping Role, this method
# handles the specifics of finding bam files for this lane. It returns a list
# of files that its found for this lane.

sub _generate_filenames {
  my ( $self, $mapstats_id, $pairing ) = @_;

  my $markdup_file = "$mapstats_id.$pairing.markdup.bam";
  my $raw_file     = "$mapstats_id.$pairing.raw.sorted.bam";

  my $returned_file;
  if ( -f file($self->storage_path, $markdup_file) ) {
    # if the markdup file exists, we show that. Note that we check that the
    # file exists using the storage path (on NFS), but return the symlink
    # path (on lustre)
    $returned_file = $markdup_file;
  }
  else {
    # if the markdup file *doesn't* exist, we fall back on the
    # ".raw.sorted.bam" file, which should always exist. If it doesn't exist
    # (check on the NFS filesystem), issue a warning, but return the path to
    # file anyway
    $returned_file = $raw_file;

    carp qq(WARNING: expected to find raw bam file at "$returned_file", but it was missing)
      unless -f file($self->storage_path, $raw_file);
  }

  return $returned_file;
}

#-------------------------------------------------------------------------------

# build a row of statistics for the current lane and specified mapstats row

sub _get_stats_row {
  my ( $self, $ms ) = @_;

  # shortcut to a hash containing Bio::Track::Schema::Result objects
  my $t = $self->_tables;

  return [
    $t->{project}->ssid,
    $t->{sample}->name,
    $self->row->name,
    $self->row->readlen,
    $self->row->raw_reads,
    $self->row->raw_bases,
    $self->_map_type($ms),
    defined $ms ? $ms->assembly->name           : undef,
    defined $ms ? $ms->assembly->reference_size : undef,
    defined $ms ? $ms->mapper->name             : undef,
    defined $ms ? $ms->mapstats_id              : undef,
    $self->_mapped_percentage($ms),
    $self->_paired_percentage($ms),
    defined $ms ? $ms->mean_insert              : undef,
    $self->_depth_of_coverage($ms),
    $self->_depth_of_coverage_sd($ms),
    defined $ms && $ms->target_bases_1x   ? sprintf( '%.1f', $ms->target_bases_1x   ) : undef,
    defined $ms && $ms->target_bases_5x   ? sprintf( '%.1f', $ms->target_bases_5x   ) : undef,
    defined $ms && $ms->target_bases_10x  ? sprintf( '%.1f', $ms->target_bases_10x  ) : undef,
    defined $ms && $ms->target_bases_50x  ? sprintf( '%.1f', $ms->target_bases_50x  ) : undef,
    defined $ms && $ms->target_bases_100x ? sprintf( '%.1f', $ms->target_bases_100x ) : undef,
  ];
}

#-------------------------------------------------------------------------------

1;

