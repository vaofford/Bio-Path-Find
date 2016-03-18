
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

with 'Bio::Path::Find::Lane::Role::Stats';

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

# make the "filetype" attribute require values of type AssemblyType. This is to
# make sure that this class correctly restrict the sorts of files that it will
# return.

has '+filetype' => (
  isa => Maybe[MapType],
);

#---------------------------------------

has 'mappers' => (
  is      => 'ro',
  isa     => Mappers,
  lazy    => 1,
  builder => '_build_mappers',
);

sub _build_mappers {
  return Mapper->values;
}

#---------------------------------------

has 'reference' => (
  is  => 'ro',
  isa => Str,
);

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# somewhere to store extra information about the files that we find. The info
# is stored as hashref, keyed on the file path.

has '_verbose_file_info' => (
  is      => 'rw',
  isa     => HashRef[ArrayRef[Str]],
  default => sub { {} },
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
#- methods ---------------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 print_details

For each bam file found by this lane, print:

=over

=item the path to the file itself

=item the reference to which reads were mapped

=item the name of the mapping software used

=item the date at which the mapping was generated

=back

The items are printed as a simple tab-separated list, one row per file.

=cut

sub print_details {
  my $self = shift;

  foreach my $file ( $self->all_files ) {
    say join "\t", $file, @{ $self->_verbose_file_info->{$file} };
  }
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# find bam files for the lane

# (This is a bit long for a single method, but it's quite convoluted and would
# just generate more code if it had to be split off sensibly into smaller
# methods.)

sub _get_bam {
  my $self = shift;

  my $lane_row = $self->row;

  my $mapstats_rows = $lane_row->search_related_rs( 'latest_mapstats', { is_qc => 0 } );

  # if there are no rows for this lane in the mapstats table, it hasn't had
  # mapping run on it, so we're done here
  return unless $mapstats_rows->count;

  MAPPING: foreach my $mapstats_row ( $mapstats_rows->all ) {

    my $mapstats_id = $mapstats_row->mapstats_id;
    my $prefix      = $mapstats_row->prefix;

    # find the path (on NFS) to the job status file for this mapping run
    my $job_status_file = file( $lane_row->storage_path, "${prefix}job_status" );

    # if the job failed or is still running, the file "<prefix>job_status" will
    # still exist, in which case we don't want to return *any* bam files
    next MAPPING if -f $job_status_file;

    # at this point there's no job status file, so the mapping job is done

    #---------------------------------------

    # apply filters

    # this is the mapper that was actually used to map this lane's reads
    my $lane_mapper = $mapstats_row->mapper->name;

    # this is the reference that was used for this particular mapping
    my $lane_reference = $mapstats_row->assembly->name;

    # return only mappings generated using a specific mapper
    if ( $self->mappers ) {
      # the user provided a list of mappers. Convert it into a hash so that
      # we can quickly look up the lane's mapper in there
      my %wanted_mappers = map { $_ => 1 } @{ $self->mappers };

      # unless the lane's mapper is one of the mappers that the user specified,
      # skip this mapping
      next MAPPING unless exists $wanted_mappers{$lane_mapper};
    }

    # return only mappings that use a specific reference genome
    next MAPPING if ( $self->reference and $lane_reference ne $self->reference );

    #---------------------------------------

    # build the name of the bam file for this mapping

    # single or paired end ?
    my $pairing = $lane_row->paired ? 'pe' : 'se';

    my $markdup_file = "$mapstats_id.$pairing.markdup.bam";
    my $raw_file = "$mapstats_id.$pairing.raw.sorted.bam";

    my $returned_file;
    if ( -f file($self->storage_path, $markdup_file) ) {
      # if the markdup file exists, we show that. Note that we check that the
      # file exists using the storage path (on NFS), but return the symlink
      # path (on lustre)
      $returned_file = file($self->symlink_path, $markdup_file);
    }
    else {
      # if the markdup file *doesn't* exist, we fall back on the
      # ".raw.sorted.bam" file, which should always exist. If it doesn't exist
      # (check on the NFS filesystem), issue a warning, but return the path to
      # file anyway
      $returned_file = file( $self->symlink_path, $raw_file );

      carp qq(WARNING: expected to find raw bam file at "$returned_file", but it was missing)
        unless -f file($self->storage_path, $raw_file);
    }

    # store the file itself, plus some extra details, which are used by the
    # "print_details" method
    $self->_add_file($returned_file);
    $self->_verbose_file_info->{$returned_file} = [
      $lane_reference,          # name of the reference
      $lane_mapper,             # name of the mapper
      $mapstats_row->changed,   # last update timestamp
    ];
  }
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

