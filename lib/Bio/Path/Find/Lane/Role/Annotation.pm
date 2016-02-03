
package Bio::Path::Find::Lane::Role::Annotation;

# ABSTRACT: a role that adds annotation-specific functionality to the B::P::F::Lane class

use Moose::Role;
use Path::Class;

use Types::Standard qw(
  ArrayRef
  HashRef
  Str
);

use Bio::Path::Find::Types qw( :types );

with 'Bio::Path::Find::Lane::Role::Stats';

#-------------------------------------------------------------------------------
#- attribute modifiers ---------------------------------------------------------
#-------------------------------------------------------------------------------

has '+filetype' => (
  isa => Maybe[AnnotationType],
);

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# =head1 ATTRIBUTES
#
# =cut

#-------------------------------------------------------------------------------
#- builders for file finding ---------------------------------------------------
#-------------------------------------------------------------------------------

# this mapping is taken from the original annotationfind
# (PathFind/lib/Path/Find/CommandLine/Annotation.pm:208)

sub _build_filetype_extensions {
  return {
    gff => '*.gff',
    faa => '*.faa',
    ffn => '*.ffn',
    gbk => '*.gbk',
  };
}

# (if there is a "_get_*" method for one of the keys, then calling
# $lane->find_files(filetype=>'<key>') will call that method to find files.  If
# there's no corresponding "_get_*" method, "find_files" will fall back on
# calling "_get_extension", which will use Find::File::Rule to look for files
# according to the pattern given in the hash value.)

#-------------------------------------------------------------------------------
#- builders for statistics gathering -------------------------------------------
#-------------------------------------------------------------------------------

# build an array of headers for the statistics report

sub _build_stats_headers {
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


# collect together the fields for the statistics report
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

#-------------------------------------------------------------------------------
#- methods for statistics gathering --------------------------------------------
#-------------------------------------------------------------------------------

# get the statistics for the specified assembler from the specified file

# sub _get_stats_row {
#   my ( $self, $assembler, $assembly_file ) = @_;
#
#   # shortcut to a hash containing Bio::Track::Schema::Result objects
#   my $t = $self->_tables;
#
#   my $assembly_dir   = dir( $self->symlink_path, "${assembler}_assembly" );
#
#   my $stats_file     = file( $assembly_dir, $assembly_file );
#   my $file_stats     = $self->_parse_stats_file($stats_file);
#
#   my $bamcheck_file  = file( $assembly_dir, 'contigs.mapped.sorted.bam.bc' );
#   my $bamcheck_stats = $self->_parse_bc_file($bamcheck_file);
#
#   return [
#     $t->{lane}->name,
#     $self->_get_assembly_type($assembly_dir, $assembly_file) || 'NA', # not sure if it's ever undef...
#     $file_stats->{total_length},
#     $file_stats->{num_contigs},
#     $file_stats->{average_contig_length},
#     $file_stats->{largest_contig},
#     $file_stats->{N50},
#     $file_stats->{N50_n},
#     $file_stats->{N60},
#     $file_stats->{N60_n},
#     $file_stats->{N70},
#     $file_stats->{N70_n},
#     $file_stats->{N80},
#     $file_stats->{N80_n},
#     $file_stats->{N90},
#     $file_stats->{N90_n},
#     $file_stats->{N100},
#     $file_stats->{N100_n},
#     $file_stats->{n_count},
#     $bamcheck_stats->{sequences},
#     $bamcheck_stats->{'reads mapped'},
#     $bamcheck_stats->{'reads unmapped'},
#     $bamcheck_stats->{'reads paired'},
#     $bamcheck_stats->{'reads unpaired'},
#     $bamcheck_stats->{'total length'},
#     $bamcheck_stats->{'bases mapped'},
#     $bamcheck_stats->{'bases mapped (cigar)'},
#     $bamcheck_stats->{'average length'},
#     $bamcheck_stats->{'maximum length'},
#     $bamcheck_stats->{'average quality'},
#     $bamcheck_stats->{'insert size average'},
#     $bamcheck_stats->{'insert size standard deviation'},
#   ];
# }

#-------------------------------------------------------------------------------

# get the string describing the assembly pipeline that was run

# sub _get_assembly_type {
#   my ( $self, $assembly_dir, $assembly_file ) = @_;
#
#   my $pipeline_description;
#   foreach ( $assembly_dir->children ) {
#     next unless m|pipeline_version_(\d+)$|;
#     $pipeline_description = $self->_pipeline_versions->{$1};
#     last if defined $pipeline_description;
#   }
#
#   return unless $pipeline_description;
#
#   my $contig_type = $assembly_file =~ m/^unscaffolded/
#                   ? 'Contig'
#                   : 'Scaffold';
#
#   return "$contig_type: $pipeline_description";
# }

#-------------------------------------------------------------------------------

# parse the stats file that comes with the assembly

# sub _parse_stats_file {
#   my ( $self, $stats_file ) = @_;
#
#   my %assembly_stats;
#   foreach ( $stats_file->slurp(chomp => 1) ) {
#     # I don't really like using regexes with lack matches like this, but at
#     # least one of these fields, "ave", can be a float, and who knows what else
#     # might be in there if things go wrong in the pipeline. Better to return
#     # everything, so that at least the end-user gets to see the bad data.
#     if ( m/^sum = (\S+), n = (\S+), ave = (\S+), largest = (\S+)/ ) {
#       $assembly_stats{total_length}          = $1;
#       $assembly_stats{num_contigs}           = $2;
#       $assembly_stats{average_contig_length} = $3;
#       $assembly_stats{largest_contig}        = $4;
#     }
#     elsif ( m/^(N\d+) = (\d+), n = (\d+)/ ) {
#       $assembly_stats{$1}          = $2;
#       $assembly_stats{ $1 . '_n' } = $3;
#     }
#     elsif ( m/^N_count = (\d+)/ ) {
#       $assembly_stats{n_count} = $1;
#     }
#   }
#
#   return \%assembly_stats;
# }

#-------------------------------------------------------------------------------

# parse the bamcheck file

# sub _parse_bc_file {
#   my ( $self, $bc_file ) = @_;
#
#   my %bc_stats;
#   foreach ( $bc_file->slurp(chomp => 1) ) {
#     # TODO not sure if this is a sensible optimisation. Do the FFQ fields
#     # TODO *always* come after the SN fields ?
#     last if m/^FFQ/;
#
#     # anyway, we're only interested in the summary numbers
#     next unless m/^SN\t(.*?):\t(\S+)/;
#
#     $bc_stats{$1} = $2;
#   }
#
#   return \%bc_stats;
# }

#-------------------------------------------------------------------------------

1;

