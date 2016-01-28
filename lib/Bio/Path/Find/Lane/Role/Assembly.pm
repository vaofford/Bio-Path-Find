
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

has 'assemblers' => (
  is => 'ro',
  isa => ArrayRef[Str],
  lazy => 1,
  builder => '_build_assemblers',
);

sub _build_assemblers {
  [ qw(
    velvet
    spades
    iva
    pacbio
  ) ];
}

# TODO need to get this list from the Types library. It's daft having it in
# TODO two places.
#
# TODO need to figure out how to set a value for "assemblers", so that we can
# TODO restrict file finding to specific assemblers

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

# NOTE if there is a "_get_*" method for one of the keys, then calling
# NOTE $lane->find_files(filetype=>'<key>') will call that method to find files.
# NOTE If there's no corresponding "_get_*" method, "find_files" will fall back
# NOTE on calling "_get_extension", which will use Find::File::Rule to look for
# NOTE files according to the pattern given in the hash value.

#-------------------------------------------------------------------------------

sub _get_scaffold {
  my $self = shift;

  $self->log->trace( q(looking for scaffolds in ") . $self->symlink_path . q(") );

  foreach my $assembler ( @{ $self->assemblers} ) {
    my $filename = file( $self->symlink_path, "${assembler}_assembly", 'contigs.fa' );
    $self->_add_file($filename) if -f $filename;
  }
}

#-------------------------------------------------------------------------------

sub _get_contigs {
  my $self = shift;

  $self->log->trace( q(looking for contigs in ") . $self->symlink_path . q(") );

  foreach my $assembler ( @{ $self->assemblers} ) {
    my $filename = file( $self->symlink_path, "${assembler}_assembly", 'unscaffolded_contigs.fa' );
    $self->_add_file($filename) if -f $filename;
  }
}

#-------------------------------------------------------------------------------

sub _get_all {
  my $self = shift;

  $self->log->trace( q(looking for scaffolds and contigs in ") . $self->symlink_path . q(") );

  $self->_get_scaffold;
  $self->_get_contigs;
}

#-------------------------------------------------------------------------------

# given a "from" and "to" filename, edit the destination to change the format
# of the filename. This gives a Role on the Lane a chance to edit the filenames
# that are used, so that they can be specialised to the type of data that the
# Role is handling.
#
# For example, this method is called by B::P::F::Role::Linker before it creates
# links. This method makes the link destination look like:
#
#   <dst_path directory> / <id>.[scaffold_]contigs_<assembler>.fa
#
# e.g.: /home/user/12345_1#1.contigs_iva.fa
#       /home/user/12345_1#1.scaffold_contigs_spades.fa

sub _edit_filenames {
  my ( $self, $src_path, $dst_path ) = @_;

  my @src_path_components = $src_path->components;

  my $id_dir        = $src_path_components[-3];
  my $assembler_dir = $src_path_components[-2];
  my $filename      = $src_path_components[-1];

  ( my $prefix    = $filename )      =~ s/\.[^.]*//;
  ( my $assembler = $assembler_dir ) =~ s/^(\w+)_assembly$/$1/;

  my $dst = file( $dst_path->dir, $id_dir . '.' . $prefix . '_' . $assembler . '.fa' );

  $DB::single = 1;

  return ( $src_path, $dst );
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

