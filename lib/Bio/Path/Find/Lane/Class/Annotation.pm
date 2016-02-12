
package Bio::Path::Find::Lane::Class::Annotation;

# ABSTRACT: a class that adds annotation-specific functionality to the B::P::F::Lane class

use Moose;
use Path::Class;

use Types::Standard qw(
  Maybe
  ArrayRef
  Str
);

use Bio::Path::Find::Types qw( :all );

extends 'Bio::Path::Find::Lane';

with 'Bio::Path::Find::Lane::Role::HasAssembly',
     'Bio::Path::Find::Lane::Role::Stats';

#-------------------------------------------------------------------------------
#- attribute modifiers ---------------------------------------------------------
#-------------------------------------------------------------------------------

# make the "filetype" attribute require values of type AnnotationType. This is
# to make sure that this class correctly restricts the sorts of files that it
# will handle/return.

has '+filetype' => (
  isa => Maybe[AnnotationType],
);

#-------------------------------------------------------------------------------
#- builders for file finding ---------------------------------------------------
#-------------------------------------------------------------------------------

# this mapping is taken from the original annotationfind
# (PathFind/lib/Path/Find/CommandLine/Annotation.pm:208)

sub _build_filetype_extensions {
  return {
    # old mapping         friendlier version...
    gff     => '*.gff',
    faa     => '*.faa',   fasta   => '*.faa',
    ffn     => '*.ffn',   fastn   => '*.ffn',
    gbk     => '*.gbk',   genbank => '*.gbk',
  };
}

# (if there is a "_get_*" method for one of the keys, then calling
# $lane->find_files(filetype=>'<key>') will call that method to find files.  If
# there's no corresponding "_get_*" method, "find_files" will fall back on
# calling "_get_files_by_extension", which will use Find::File::Rule to look
# for files according to the pattern given in the hash value.)

#-------------------------------------------------------------------------------
#- builders for statistics gathering -------------------------------------------
#-------------------------------------------------------------------------------

# build an array of headers for the statistics report
#
# required by the Stats Role

sub _build_stats_headers {
  return [
    'Study ID',
    'Assembly Type',
    'Lane Name',
    'Reads',
    'Reference',
    'Reference Size',
    'Mapped %',
    'Depth of Coverage',
    'Adapter %',
    'Total Length',
    'No Contigs',
    'N50',
    'Reads Mapped',
    'Average Quality',
    'No. genes',
    'No. CDS genes',
  ];
}

#-------------------------------------------------------------------------------

# collect together the fields for the statistics report
#
# required by the Stats Role

sub _build_stats {
  my $self = shift;

  my @rows;
  foreach my $assembler ( @{ $self->assemblers } ) {

    my $assembly_dir = dir( $self->symlink_path, "${assembler}_assembly" );
    next unless -d $assembly_dir;

    foreach my $gff_file_path ( @{ $self->files } ) {
      my $gff_file = file $gff_file_path;

      # don't show stats for this assembler unless the GFF file is actually in
      # the assembler's output directory
      next unless $assembly_dir->subsumes($gff_file);

      foreach my $assembly_file ( @{ $self->_assembly_files } ) {
        push @rows, $self->_get_stats_row( $assembler, $assembly_file, $gff_file );
      }
    }

  }

  return \@rows;
}

#-------------------------------------------------------------------------------
#- methods for statistics gathering --------------------------------------------
#-------------------------------------------------------------------------------

# get the statistics for the specified assembler from the specified file

sub _get_stats_row {
  my ( $self, $assembler, $assembly_file, $gff_file ) = @_;

  # shortcut to a hash containing Bio::Track::Schema::Result objects
  my $t = $self->_tables;

  my $assembly_dir   = dir( $self->symlink_path, "${assembler}_assembly" );

  my $stats_file     = file( $assembly_dir, $assembly_file );
  my $file_stats     = $self->_parse_stats_file($stats_file);

  my $bamcheck_file  = file( $assembly_dir, 'contigs.mapped.sorted.bam.bc' );
  my $bamcheck_stats = $self->_parse_bc_file($bamcheck_file);

  my $gff_stats      = $self->_parse_gff_file($gff_file);

  return [
    $t->{project}->ssid,
    $self->_get_assembly_type($assembly_dir, $assembly_file) || 'NA', # not sure if it's ever undef...
    $t->{lane}->name,
    $t->{lane}->raw_reads,
    $t->{assembly}->name,
    $t->{assembly}->reference_size,
    $self->_mapped_percentage,
    $self->_depth_of_coverage,
    $self->_adapter_percentage,
    $file_stats->{total_length},
    $file_stats->{num_contigs},
    $file_stats->{N50},
    $bamcheck_stats->{'reads mapped'},
    $bamcheck_stats->{'average quality'},
    $gff_stats->{gene_count},
    $gff_stats->{cds_count},
  ];
}

#-------------------------------------------------------------------------------

1;

