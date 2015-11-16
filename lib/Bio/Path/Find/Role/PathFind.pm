
package Bio::Path::Find::Role::PathFind;

# ABSTRACT: a role that collects together statistics for a lane

# this Role produces statistics appropriate for the pathfind script

use Moose::Role;
use Path::Class;

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
    $self->_het_snp_stats, # returns 4 values
    $self->pipeline_status('qc'),
    $self->pipeline_status('mapped'),
    $self->pipeline_status('stored'),
    $self->pipeline_status('snp_called'),
    $self->pipeline_status('snp_called'),
    $self->pipeline_status('assembled'),
    $self->pipeline_status('annotated'),
  ];
}

#-------------------------------------------------------------------------------

1;

