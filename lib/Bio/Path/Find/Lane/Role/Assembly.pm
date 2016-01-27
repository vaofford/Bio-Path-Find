
package Bio::Path::Find::Lane::Role::Assembly;

# ABSTRACT: a role that adds assembly-specific functionality to the B::P::F::Lane class

use Moose::Role;
use Path::Class;

use Types::Standard qw(
  ArrayRef
  Str
);

with 'Bio::Path::Find::Lane::Role::Stats';

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

has 'known_assemblers' => (
  is => 'ro',
  isa => ArrayRef[Str],
  lazy => 1,
  builder => '_build_known_assemblers',
);

sub _build_known_assemblers {
  [ qw(
    velvet
    spades
    iva
    pacbio
  ) ];
}

#-------------------------------------------------------------------------------
#- builders --------------------------------------------------------------------
#-------------------------------------------------------------------------------

# this taken from original assemblyfind
# (PathFind/lib/Path/Find/CommandLine/Assembly.pm:193)

sub _build_filetype_extensions {
  {
    contigs  => 'unscaffolded_contigs.fa',
    scaffold => 'contigs.ga',
    all      => '*contigs.fa',
  };
}

#-------------------------------------------------------------------------------

sub _get_scaffold {
  my $self = shift;

  $self->log->trace( q(looking for scaffolds in ") . $self->symlink_path . q(") );

  foreach my $assembler ( @{ $self->known_assemblers} ) {
    my $filename = file( $self->symlink_path, "${assembler}_assembly", 'contigs.fa' );
    $self->_add_file($filename) if -f $filename;
  }
}

#-------------------------------------------------------------------------------

sub _get_contig {
  my $self = shift;

  $self->log->trace( q(looking for contigs in ") . $self->symlink_path . q(") );

  foreach my $assembler ( @{ $self->known_assemblers} ) {
    my $filename = file( $self->symlink_path, "${assembler}_assembly", 'unscaffolded_contigs.fa' );
    $self->_add_file($filename) if -f $filename;
  }
}

#-------------------------------------------------------------------------------

sub _get_all {
  my $self = shift;

  $self->log->trace( q(looking for scaffolds and contigs in ") . $self->symlink_path . q(") );

  $self->_get_scaffold;
  $self->_get_contig;
}

#-------------------------------------------------------------------------------

# build an array of headers for the statistics display
sub _build_stats_headers {
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

#-------------------------------------------------------------------------------

# collect together the fields for the statistics display
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

