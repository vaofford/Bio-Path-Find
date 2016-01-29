
package Bio::Path::Find::Lane::Role::Assembly;

# ABSTRACT: a role that adds assembly-specific functionality to the B::P::F::Lane class

use Moose::Role;
use Path::Class;

use Types::Standard qw(
  ArrayRef
  HashRef
  Str
);

use Bio::Path::Find::Types qw(
  AssemblyType
  Assembler
);

with 'Bio::Path::Find::Lane::Role::Stats';

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

=attr assemblers

A list of names of assemblers that the assembly-related code understands. The
default list is:

=over

=item velvet

=item spades

=item iva

=item pacbio

=back

=cut

has 'assemblers' => (
  is => 'rw',
  isa => ArrayRef[Assembler],
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

# TODO ideally we need to get this list from the Types library. It's daft
# TODO having it in two places

#---------------------------------------

=attr assembly_type

The "type" of this assembly, either C<scaffold> or C<contigs>, or C<all> for
both.

=cut

has 'assembly_type' => (
  is      => 'rw',
  isa     => AssemblyType,
  default => 'scaffold',
  trigger => \&_register_assembly_files,
);

sub _register_assembly_files {
  my ( $self, $assembly_type, $old_assembly_type ) = shift;

  if ( defined $assembly_type ) {
    if ( $assembly_type eq 'scaffold' ) {
      $self->_set_assembly_files( [ 'unscaffolded_contigs.fa.stats', 'contigs.fa.stats' ] );
    }
    elsif ( $assembly_type eq 'contigs' ) {
      $self->_set_assembly_files( [ 'unscaffolded_contigs.fa.stats' ] );
    }
  }
  else { # $assembly_type eq 'scaffold'
    $self->_set_assembly_files( [ 'contigs.fa.stats' ] );
  }
}

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# the list of files
has '_assembly_files' => (
  is => 'ro',
  isa => ArrayRef[Str],
  writer => '_set_assembly_files',
  default => sub { [ 'contigs.fa.stats' ] },
);

#---------------------------------------

has '_pipeline_versions' => (
  is      => 'ro',
  isa     => HashRef,
  lazy    => 1,
  builder => '_build_pipeline_versions',
);

sub _build_pipeline_versions {
  return {
    '2.0.0' => 'Velvet',
    '2.0.1' => 'Velvet + Improvement',
    '2.1.0' => 'Correction, Normalisation, Primer Removal + Velvet',
    '2.1.1' => 'Correction, Normalisation, Primer Removal + Velvet + Improvement',
    '2.2.0' => 'Correction, Normalisation + Velvet',
    '2.2.1' => 'Correction, Normalisation + Velvet + Improvement',
    '2.3.0' => 'Correction, Primer Removal + Velvet',
    '2.3.1' => 'Correction, Primer Removal + Velvet + Improvement',
    '2.4.0' => 'Normalisation, Primer Removal + Velvet',
    '2.4.1' => 'Normalisation, Primer Removal + Velvet + Improvement',
    '2.5.0' => 'Correction + Velvet',
    '2.5.1' => 'Correction + Velvet + Improvement',
    '2.6.0' => 'Normalisation + Velvet',
    '2.6.1' => 'Normalisation + Velvet + Improvement',
    '2.7.0' => 'Primer Removal + Velvet',
    '2.7.1' => 'Primer Removal + Velvet + Improvement',
    '3.0.0' => 'SPAdes',
    '3.0.1' => 'SPAdes + Improvement',
    '3.1.0' => 'Correction, Normalisation, Primer Removal + SPAdes',
    '3.1.1' => 'Correction, Normalisation, Primer Removal + SPAdes + Improvement',
    '3.2.0' => 'Correction, Normalisation + SPAdes',
    '3.2.1' => 'Correction, Normalisation + SPAdes + Improvement',
    '3.3.0' => 'Correction, Primer Removal + SPAdes',
    '3.3.1' => 'Correction, Primer Removal + SPAdes + Improvement',
    '3.4.0' => 'Normalisation, Primer Removal + SPAdes',
    '3.4.1' => 'Normalisation, Primer Removal + SPAdes + Improvement',
    '3.5.0' => 'Correction + SPAdes',
    '3.5.1' => 'Correction + SPAdes + Improvement',
    '3.6.0' => 'Normalisation + SPAdes',
    '3.6.1' => 'Normalisation + SPAdes + Improvement',
    '3.7.0' => 'Primer Removal + SPAdes',
    '3.7.1' => 'Primer Removal + SPAdes + Improvement',
    '5.0.0' => 'IVA',
    '5.0.1' => 'IVA + Improvement',
    '5.1.0' => 'Correction, Normalisation, Primer Removal + IVA',
    '5.1.1' => 'Correction, Normalisation, Primer Removal + IVA + Improvement',
    '5.2.0' => 'Correction, Normalisation + IVA',
    '5.2.1' => 'Correction, Normalisation + IVA + Improvement',
    '5.3.0' => 'Correction, Primer Removal + IVA',
    '5.3.1' => 'Correction, Primer Removal + IVA + Improvement',
    '5.4.0' => 'Normalisation, Primer Removal + IVA',
    '5.4.1' => 'Normalisation, Primer Removal + IVA + Improvement',
    '5.5.0' => 'Correction + IVA',
    '5.5.1' => 'Correction + IVA + Improvement',
    '5.6.0' => 'Normalisation + IVA',
    '5.6.1' => 'Normalisation + IVA + Improvement',
    '5.7.0' => 'Primer Removal + IVA',
    '5.7.1' => 'Primer Removal + IVA + Improvement',
    '2'     => 'Velvet + Improvement',
    '2.1'   => 'Velvet + Improvement',
    '3'     => 'Correction, Normalisation, Primer Removal + SPAdes + Improvement',
    '3.1'   => 'Correction, Normalisation, Primer Removal + Velvet + Improvement',
    '3.2'   => 'Normalisation + SPAdes + Improvement',
    '4'     => 'Correction + Velvet + Improvement',
    '5'     => 'IVA',
    '6.0'   => 'SMRT analysis 2.2.0'
  };
}

#-------------------------------------------------------------------------------
#- builders --------------------------------------------------------------------
#-------------------------------------------------------------------------------

# this sets the mapping between filetype and patterns matching filenames on
# disk. It's potentially used by B::P::F::Lane objects to find files when no
# filetype is specified but, in fact, the mechanism for finding assemblies is
# actually set up to use the three "_get_*" methods below, so the mapping is
# redundant. It's only here for consistency.
#
# this mapping is taken from the original assemblyfind
# (PathFind/lib/Path/Find/CommandLine/Assembly.pm:193)

sub _build_filetype_extensions {
  {
    contigs  => 'unscaffolded_contigs.fa',
    scaffold => 'contigs.ga',
    all      => '*contigs.fa',
  };
}

# (if there is a "_get_*" method for one of the keys, then calling
# $lane->find_files(filetype=>'<key>') will call that method to find files.  If
# there's no corresponding "_get_*" method, "find_files" will fall back on
# calling "_get_extension", which will use Find::File::Rule to look for files
# according to the pattern given in the hash value.)

#-------------------------------------------------------------------------------

# these methods are used by B::P::F::Finder when looking for assembly-related
# files on disk

sub _get_scaffold {
  my $self = shift;

  $self->log->trace( q(looking for scaffolds in ") . $self->symlink_path . q(") );

  foreach my $assembler ( @{ $self->assemblers} ) {
    my $filename = file( $self->symlink_path, "${assembler}_assembly", 'contigs.fa' );
    $self->_add_file($filename) if -f $filename;
  }
}

#---------------------------------------

sub _get_contigs {
  my $self = shift;

  $self->log->trace( q(looking for contigs in ") . $self->symlink_path . q(") );

  foreach my $assembler ( @{ $self->assemblers} ) {
    my $filename = file( $self->symlink_path, "${assembler}_assembly", 'unscaffolded_contigs.fa' );
    $self->_add_file($filename) if -f $filename;
  }
}

#---------------------------------------

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
    'Lane',
    'Assembly Type',
    'Total Length',
    'No Contigs',
    'Avg Contig Length',
    'Largest Contig',
    'N50',
    'Contigs in N50',
    'N60',
    'Contigs in N60',
    'N70',
    'Contigs in N70',
    'N80',
    'Contigs in N80',
    'N90',
    'Contigs in N90',
    'N100',
    'Contigs in N100',
    'No scaffolded bases (N)',
    'Total Raw Reads',
    'Reads Mapped',
    'Reads Unmapped',
    'Reads Paired',
    'Reads Unpaired',
    'Total Raw Bases',
    'Total Bases Mapped',
    'Total Bases Mapped (Cigar)',
    'Average Read Length',
    'Maximum Read Length',
    'Average Quality',
    'Insert Size Average',
    'Insert Size Std Dev',
  ];
}

#-------------------------------------------------------------------------------

# collect together the fields for the statistics display
sub _build_stats {
  my $self = shift;

  my @rows;
  foreach my $assembler ( @{ $self->assemblers } ) {

    my $assembly_dir = dir( $self->symlink_path, "${assembler}_assembly" );
    next unless -d $assembly_dir;

    foreach my $assembly_file ( @{ $self->_assembly_files } ) {
      push @rows, $self->_get_stats_row( $assembler, $assembly_file );
    }

  }

  return \@rows;
}

sub _get_stats_row {
  my ( $self, $assembler, $assembly_file ) = @_;

  # shortcut to a hash containing Bio::Track::Schema::Result objects
  my $t = $self->_tables;

  return [
    $t->{lane}->name,
    $self->_get_assembly_type( $assembler, $assembly_file ),
#     'Total Length',
#     'No Contigs',
#     'Avg Contig Length',
#     'Largest Contig',
#     'N50',
#     'Contigs in N50',
#     'N60',
#     'Contigs in N60',
#     'N70',
#     'Contigs in N70',
#     'N80',
#     'Contigs in N80',
#     'N90',
#     'Contigs in N90',
#     'N100',
#     'Contigs in N100',
#     'No scaffolded bases (N)',
#     'Total Raw Reads',
#     'Reads Mapped',
#     'Reads Unmapped',
#     'Reads Paired',
#     'Reads Unpaired',
#     'Total Raw Bases',
#     'Total Bases Mapped',
#     'Total Bases Mapped (Cigar)',
#     'Average Read Length',
#     'Maximum Read Length',
#     'Average Quality',
#     'Insert Size Average',
#     'Insert Size Std Dev',
#
#     $t->{project}->ssid,
#     $t->{sample}->name,
#     $t->{lane}->readlen,
#     $t->{lane}->raw_reads,
#     $t->{lane}->raw_bases,
#     $self->_map_type,
#     defined $t->{assembly} ? $t->{assembly}->name           : undef,
#     defined $t->{assembly} ? $t->{assembly}->reference_size : undef,
#     defined $t->{mapper}   ? $t->{mapper}->name             : undef,
#     defined $t->{mapstats} ? $t->{mapstats}->mapstats_id    : undef,
#     $self->_mapping_is_complete
#       ? $self->_percentage( $t->{mapstats}->reads_mapped, $t->{mapstats}->raw_reads )
#       : '0.0',
#     $self->_mapping_is_complete
#       ? $self->_percentage( $t->{mapstats}->reads_paired, $t->{mapstats}->raw_reads )
#       : '0.0',
#     $t->{mapstats}->mean_insert,
#     $self->_depth_of_coverage,
#     $self->_depth_of_coverage_sd,
#     $self->_adapter_percentage,
#     $self->_transposon_percentage,
#     $self->_genome_covered,
#     $self->_duplication_rate,
#     $self->_error_rate,
#     $t->{lane}->npg_qc_status,
#     $t->{lane}->qc_status,
#     $self->_het_snp_stats, # returns 4 values
#     $self->pipeline_status('qc'),
#     $self->pipeline_status('mapped'),
#     $self->pipeline_status('stored'),
#     $self->pipeline_status('snp_called'),
#     $self->pipeline_status('snp_called'),
#     $self->pipeline_status('assembled'),
#     $self->pipeline_status('annotated'),
  ];
}

#-------------------------------------------------------------------------------
#- methods that return stats values --------------------------------------------
#-------------------------------------------------------------------------------

sub _get_assembly_type {
  my ( $self, $assembler, $assembly_file ) = @_;

  my $assembly_dir = dir( $self->symlink_path, "${assembler}_assembly" );

  my $pipeline_version;
  foreach ( $assembly_dir->children ) {
    next unless m|pipeline_version_(\d+)$|;
    $pipeline_version = $self->_pipeline_versions->{$1};
    last if defined $pipeline_version;
  }

  return unless defined $pipeline_version;

  my $contig_type = $assembly_file =~ m/^unscaffolded/
                  ? 'Contig'
                  : 'Scaffold';

  return "$contig_type: $pipeline_version";
}

#-------------------------------------------------------------------------------

1;

