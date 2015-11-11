
package Bio::Path::Find::Role::Stats::Path;

use Moose::Role;

with 'Bio::Path::Find::Role::Stats';

sub _build_headers {
  my $self = shift;

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
    'Adapter %',
    'Transposon %',
    'Genome Covered',
    'Duplication Rate',
    'Error Rate',
    'NPG QC',
    'Manual QC',
    'No. Het SNPs',
    '% Het SNPs (Total Genome)',
    '% Het SNPs (Genome Covered)',
    '% Het SNPs (Total No. of SNPs)',
    'QC Pipeline',
    'Mapping Pipeline',
    'Archiving Pipeline',
    'SNP Calling Pipeline',
    'RNASeq Pipeline',
    'Assembly Pipeline',
    'Annotation Pipeline',
  ];
}

sub _build_stats {
  my $self = shift;

  # shortcut to a hash containing Bio::Track::Schema::Result objects
  my $t = $self->_tables;

  return [
    $t->{project}->ssid,
    $t->{sample}->name,
    $t->{lane}->name,
    $t->{lane}->readlen,
    $t->{lane}->raw_reads,
    $t->{lane}->raw_bases,
    $self->_map_type,
    defined $t->{assembly} ? $t->{assembly}->name           : undef,
    defined $t->{assembly} ? $t->{assembly}->reference_size : undef,
    defined $t->{mapper}   ? $t->{mapper}->name             : undef,
    defined $t->{mapstats} ? $t->{mapstats}->mapstats_id    : undef,
    $self->_mapping_is_complete
      ? $self->_percentage( $t->{mapstats}->reads_mapped, $t->{mapstats}->raw_reads )
      : '0.0',
    $self->_mapping_is_complete
      ? $self->_percentage( $t->{mapstats}->reads_paired, $t->{mapstats}->raw_reads )
      : '0.0',
    $t->{mapstats}->mean_insert,
    $self->_depth_of_coverage,
    $self->_depth_of_coverage_sd,
    $self->_adapter_percentage,
    $self->_transposon_percentage,
    $self->_genome_covered,
    $self->_duplication_rate,
    $self->_error_rate,
    $t->{lane}->npg_qc_status,
    $t->{lane}->qc_status,
    # TODO need to read the _heterozygous_snps_report.txt file for the lane
  ];
}

#-------------------------------------------------------------------------------
#- methods ---------------------------------------------------------------------
#-------------------------------------------------------------------------------

# methods that return specific fields

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


# sub _mapped_percentage {
#   my $self = shift;
#
#   return '0.0' unless $self->_mapping_is_complete;
#
#   my $reads_mapped = $self->_tables->{mapstats}->reads_mapped;
#   my $raw_reads    = $self->_tables->{mapstats}->raw_reads;
#
#   return $self->_trim(
#     sprintf '%.1f', ( $reads_mapped / $raw_reads ) * 100
#   );
# }

# sub _paired_percentage {
#   my $self = shift;
#
#   return '0.0' unless $self->_mapping_is_complete;
#
#   my $reads_paired = $self->_tables->{mapstats}->reads_paired;
#   my $raw_reads    = $self->_tables->{mapstats}->raw_reads;
#
#   return $self->_trim(
#     sprintf '%.1f', ( $reads_paired / $raw_reads ) * 100
#   );
# }

1;

