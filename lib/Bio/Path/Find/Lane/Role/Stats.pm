
package Bio::Path::Find::Lane::Role::Stats;

# ABSTRACT: a role that provides methods for retrieving and formatting statistics about lanes

use Moose::Role;

use Path::Class;

use Types::Standard qw(
  ArrayRef
  HashRef
  Str
  Int
  Bool
);

use Bio::Path::Find::Types qw(
  BioTrackSchemaResultBase
);

requires '_build_stats_headers',
         '_build_stats';

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=attr headers

Reference to an array containing column headers for stats output.

=cut

has 'stats_headers' => (
  is      => 'ro',
  isa     => ArrayRef[Str],
  lazy    => 1,
  builder => '_build_stats_headers',
);

#---------------------------------------

=attr stats

Reference to an array containing stats. Column order is the same as in
L<headers>.

=cut

has 'stats' => (
  is      => 'ro',
  isa     => ArrayRef[ArrayRef],
  lazy    => 1,
  builder => '_build_stats',
);

#---------------------------------------

# specify that the stats should be taken from QC, rather than mapping. Default
# true

has 'use_qc_stats' => (
  is      => 'ro',
  isa     => Bool,
  default => 1,
);

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# a hash ref with table name as key and the Bio::Track::Schema::Result for that
# table as the value. Essentially just a shortcut to having to write out the
# full chain of relationships everywhere.

has '_tables' => (
  is      => 'ro',
  isa     => HashRef[BioTrackSchemaResultBase],
  lazy    => 1,
  builder => '_build_tables',
);

sub _build_tables {
  my $self = shift;

  my $t = {};

  $t->{lane}     = $self->row;
  $t->{library}  = $self->row->latest_library;
  $t->{sample}   = $self->row->latest_library->latest_sample;
  $t->{project}  = $self->row->latest_library->latest_sample->latest_project;

  # there may be multiple rows in the mapstats table for each lane,
  # representing a QC versus full mappings. Get just one row, corresponding to
  # the "use_qc_stats" attribute
  my $mapstats_rs = $self->row->search_related(
    'latest_mapstats',
    { is_qc => $self->use_qc_stats },
  );

  my ( $assembly, $mapper );
  if ( defined $mapstats_rs ) {
    $t->{mapstats} = $mapstats_rs->single;
    $t->{assembly} = $t->{mapstats}->assembly;
    $t->{mapper}   = $t->{mapstats}->mapper;
  }

  return $t;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# these are all methods that return specific fields

#-------------------------------------------------------------------------------

sub _map_type {
  my $self = shift;
  return 'NA' if not defined $self->_tables->{mapstats};
  return $self->_tables->{mapstats}->is_qc ? 'QC' : 'Mapping';
}

#-------------------------------------------------------------------------------

# (see old Path::Find::Stats::Row, line 582)

sub _depth_of_coverage {
  my $self = shift;

  return 'NA' unless $self->_is_mapped;

  # the line above is intended to be equivalent to:
  # return 'NA' unless ( defined $self->_tables->{mapstats} and
  #                      $self->_tables->{mapstats}->is_qc  and
  #                      $self->_mapping_is_complete );

  # see if we can get the value directly from the mapstats table
  my $depth              = $self->_tables->{mapstats}->mean_target_coverage;

  # we need either to lookup the depth or calculate it; see if the DB can give
  # us the genome size
  my $genome_size        = $self->_tables->{assembly}->reference_size;

  # we don't have a depth value from the DB and can't calculate it without
  # knowing the size of the genome, so bail
  return 'NA' unless ( defined $depth or $genome_size );

  my $rmdup_bases_mapped = $self->_tables->{mapstats}->rmdup_bases_mapped;
  my $qc_bases           = $self->_tables->{mapstats}->raw_bases;
  my $bases              = $self->_tables->{lane}->raw_bases;

  # if we don't already have depth then calculate it from mapped bases / genome
  # size
  $depth ||= $rmdup_bases_mapped / $genome_size;

  # scale by lane bases / sample bases
  $depth = ( $depth * $bases ) / $qc_bases;

  return $self->_trimf( $depth );
}

#-------------------------------------------------------------------------------

# (see old Path::Find::Stats::Row, line 611)

sub _depth_of_coverage_sd {
  my $self = shift;

  return 'NA' unless $self->_is_mapped;

  # see if we can get the value directly from the mapstats table
  my $depth_sd = $self->_tables->{mapstats}->target_coverage_sd;

  # we don't have a depth SD value from the DB so bail
  return 'NA' if not defined $depth_sd;

  my $qc_bases = $self->_tables->{mapstats}->raw_bases;
  my $bases    = $self->_tables->{lane}->raw_bases;

  # scale by lane bases / sample bases
  $depth_sd = ( $depth_sd * $bases ) / $qc_bases;

  return $self->_trimf( $depth_sd );
}

#-------------------------------------------------------------------------------

sub _adapter_percentage {
  my $self = shift;

  my $ms = $self->_tables->{mapstats};

  # can't calculate this value unless:
  # 1. there are stats for this lane
  # 2. it's QC'd (?)
  # 3. we can get the number of adapter reads, and
  # 4. number of raw reads
  return 'NA' unless ( defined $ms        and
                       $ms->is_qc         and
                       $ms->adapter_reads and
                       $ms->raw_reads );

  return $self->_percentage( $ms->adapter_reads, $ms->raw_reads );
}

#-------------------------------------------------------------------------------

sub _transposon_percentage {
  my $self = shift;

  my $ms = $self->_tables->{mapstats};

  return 'NA' unless ( defined $ms and
                       $ms->is_qc  and
                       $ms->percentage_reads_with_transposon );

  return $self->_trimf( $ms->percentage_reads_with_transposon, '%.1f' );
}

#-------------------------------------------------------------------------------

sub _genome_covered {
  my $self = shift;

  return 'NA' unless $self->_is_mapped;

  my $target_bases_mapped = $self->_tables->{mapstats}->target_bases_mapped;
  my $genome_size         = $self->_tables->{assembly}->reference_size;

  return 'NA' unless ( $target_bases_mapped and
                       $genome_size );

  return $self->_percentage( $target_bases_mapped, $genome_size, '%5.2f' );
}

#-------------------------------------------------------------------------------

sub _duplication_rate {
  my $self = shift;

  return 'NA' unless $self->_is_mapped;

  my $rmdup_reads_mapped = $self->_tables->{mapstats}->rmdup_reads_mapped;
  my $reads_mapped       = $self->_tables->{mapstats}->reads_mapped;

  return 'NA' unless ( $rmdup_reads_mapped and
                       $reads_mapped );

  $self->_trimf( 1 - ( $rmdup_reads_mapped / $reads_mapped ), '%.4f' );
}

#-------------------------------------------------------------------------------

sub _error_rate {
  my $self = shift;

  return 'NA' unless $self->_is_mapped;
  return $self->_trimf( $self->_tables->{mapstats}->error_rate, '%.3f' );
}

#-------------------------------------------------------------------------------

sub _het_snp_stats {
  my $self = shift;

  my $report_file = file(
    $self->symlink_path,
    $self->row->hierarchy_name . '_heterozygous_snps_report.txt'
  );

  return qw( NA NA NA NA ) unless -f $report_file;

  my @lines = $report_file->slurp(chomp => 1);

  return split m/\t/, $lines[1];
}

#-------------------------------------------------------------------------------
#- utility methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# these are all utility methods, which format, edit or tidy parameters, rather
# than retrieving or generating fields

# TODO properly validate the parameters that are passed into all of these
# TODO methods. Use Type::Tiny to check

#-------------------------------------------------------------------------------

# returns true if:
# 1. we have a mapstats row for this lane
# 2. the stats are for a QC mapping, and
# 3. the mapping is complete

sub _is_mapped {
  my $self = shift;

  return 1 if ( defined $self->_tables->{mapstats} and
                $self->_tables->{mapstats}->is_qc  and
                $self->_mapping_is_complete );
}

#-------------------------------------------------------------------------------

# returns the input string trimmed of whitespace at start and end

sub _trim {
  my ( $self, $string ) = @_;
  $string =~ s/^\s+|\s+$//g;
  return $string;
}

#-------------------------------------------------------------------------------

# returns the input string trimmed of whitespace and formatted according to the
# supplied sprintf format. Default format is '%.2f' if omitted.

sub _trimf {
  my ( $self, $string, $format ) = @_;
  $format ||= '%.2f';
  return $self->_trim( sprintf $format, $string );
}

#-------------------------------------------------------------------------------

# returns true if the lane has mapstats and the "bases_mapped" flag is true

sub _mapping_is_complete {
  my $self = shift;
  return undef if not defined $self->_tables->{mapstats};
  return $self->_tables->{mapstats}->bases_mapped ? 1 : 0;
}

#-------------------------------------------------------------------------------

# given two values, $a and $b, returns $a as a percentage of $b, formatted
# according to the supplied sprintf format. Default format is '%.1f' if
# ommitted.

sub _percentage {
  my ( $self, $a, $b, $format ) = @_;
  $format ||= '%.1f';
  return $self->_trim( sprintf $format, ( $a / $b ) * 100 );
}

#-------------------------------------------------------------------------------

1;

