
package Bio::Path::Find::Lane::Role::HasAssembly;

# ABSTRACT: a role that provides functionality related to assemblies

use Moose::Role;

use Path::Class;

use Types::Standard qw(
  ArrayRef
  HashRef
  Str
);

use Bio::Path::Find::Types qw( :all );

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

=attr assemblers

A list of names of assemblers that the assembly-related code understands. The
default list is taken from the definition of the C<Assemblers> type in the
L<type library|Bio::Path::Find::Types>:

=over

=item iva

=item pacbio

=item spades

=item velvet

=back

=cut

has 'assemblers' => (
  is      => 'rw',
  isa     => Assemblers->plus_coercions(AssemblerToAssemblers),
  coerce  => 1,
  lazy    => 1,
  builder => '_build_assemblers',
);

sub _build_assemblers {
  return Assembler->values;
}

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

# the list of files. This is set up by the trigger on the "assembly_type"
# attribute.

has '_assembly_files' => (
  is      => 'ro',
  isa     => ArrayRef[Str],
  writer  => '_set_assembly_files',
  default => sub { ['contigs.fa.stats'] },
);

#---------------------------------------

# a mapping between the "version number" for the assembly pipeline that was run
# and a description string

has '_pipeline_versions' => (
  is      => 'ro',
  isa     => HashRef,
  lazy    => 1,
  builder => '_build_pipeline_versions',
);

# TODO we could get thisfrom the config, but that would mean passing in the
# TODO config hash when we instantiate the Lane, which would have to be done
# TODO in the B::P::F::Finder::find_lanes method

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
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

sub _parse_gff_file {
  my ( $self, $gff ) = @_;

  my $gene_count = 0;
  my $cds_count = 0;
  foreach ( $gff->slurp ) {
    last if m/^##FASTA/;
    $gene_count++ unless m/^##/;
    $cds_count++ if m/CDS/;
  }

  return {
    gene_count => $gene_count,
    cds_count  => $cds_count,
  };
}

#-------------------------------------------------------------------------------

# get the string describing the assembly pipeline that was run

sub _get_assembly_type {
  my ( $self, $assembly_dir, $assembly_file ) = @_;

  my $pipeline_description;
  foreach ( $assembly_dir->children ) {
    next unless m|pipeline_version_(\d+)$|;
    $pipeline_description = $self->_pipeline_versions->{$1};
    last if defined $pipeline_description;
  }

  return unless $pipeline_description;

  my $contig_type = $assembly_file =~ m/^unscaffolded/
                  ? 'Contig'
                  : 'Scaffold';

  return "$contig_type: $pipeline_description";
}

#-------------------------------------------------------------------------------

# parse the stats file that comes with the assembly

sub _parse_stats_file {
  my ( $self, $stats_file ) = @_;

  my %assembly_stats;
  foreach ( $stats_file->slurp(chomp => 1) ) {
    # I don't really like using regexes with lack matches like this, but at
    # least one of these fields, "ave", can be a float, and who knows what else
    # might be in there if things go wrong in the pipeline. Better to return
    # everything, so that at least the end-user gets to see the bad data.
    if ( m/^sum = (\S+), n = (\S+), ave = (\S+), largest = (\S+)/ ) {
      $assembly_stats{total_length}          = $1;
      $assembly_stats{num_contigs}           = $2;
      $assembly_stats{average_contig_length} = $3;
      $assembly_stats{largest_contig}        = $4;
    }
    elsif ( m/^(N\d+) = (\d+), n = (\d+)/ ) {
      $assembly_stats{$1}          = $2;
      $assembly_stats{ $1 . '_n' } = $3;
    }
    elsif ( m/^N_count = (\d+)/ ) {
      $assembly_stats{n_count} = $1;
    }
  }

  return \%assembly_stats;
}

#-------------------------------------------------------------------------------

# parse the bamcheck file

sub _parse_bc_file {
  my ( $self, $bc_file ) = @_;

  my %bc_stats;
  foreach ( $bc_file->slurp(chomp => 1) ) {
    # TODO not sure if this is a sensible optimisation. Do the FFQ fields
    # TODO *always* come after the SN fields ?
    last if m/^FFQ/;

    # anyway, we're only interested in the summary numbers
    next unless m/^SN\t(.*?):\t(\S+)/;

    $bc_stats{$1} = $2;
  }

  return \%bc_stats;
}

#-------------------------------------------------------------------------------

1;

