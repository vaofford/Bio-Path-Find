
package Bio::Path::Find::Lane::Class::Assembly;

# ABSTRACT: a class that adds assembly-specific functionality to the B::P::F::Lane class

use Moose;
use Path::Class;

use Types::Standard qw(
  ArrayRef
  HashRef
  Str
  Maybe
);

use Bio::Path::Find::Types qw( :all );

extends 'Bio::Path::Find::Lane';

with 'Bio::Path::Find::Lane::Role::Stats',
     'Bio::Path::Find::Lane::Role::HasAssembly';

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

# make the "filetype" attribute require values of type AssemblyType. This is to
# make sure that this class correctly restrict the sorts of files that it will
# return.

has '+filetype' => (
  isa => Maybe[AssemblyType],
);

#-------------------------------------------------------------------------------
#- builders for file finding ---------------------------------------------------
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
  return {
    contigs  => 'unscaffolded_contigs.fa',
    scaffold => 'contigs.fa',
    all      => '*contigs.fa',
  };
}

# (if there is a "_get_*" method for one of the keys, then calling
# $lane->find_files(filetype=>'<key>') will call that method to find files.  If
# there's no corresponding "_get_*" method, "find_files" will fall back on
# calling "_get_files_by_extension", which will use Find::File::Rule to look
# for files according to the pattern given in the hash value.)

#-------------------------------------------------------------------------------
#- methods for file finding ----------------------------------------------------
#-------------------------------------------------------------------------------

# these methods are used by B::P::F::Finder when looking for assembly-related
# files on disk

sub _get_scaffold {
  my $self = shift;

  $self->log->trace( q(looking for scaffolds in ") . $self->symlink_path . q(") );

  foreach my $assembler ( @{ $self->assemblers} ) {
    my $filename = file( $self->symlink_path, "${assembler}_assembly", 'contigs.fa' );
    $self->_add_file($filename) if( -f $filename || -l $filename);
  }
}

#---------------------------------------

sub _get_contigs {
  my $self = shift;

  $self->log->trace( q(looking for contigs in ") . $self->symlink_path . q(") );

  foreach my $assembler ( @{ $self->assemblers} ) {
    my $filename = file( $self->symlink_path, "${assembler}_assembly", 'unscaffolded_contigs.fa' );
    $self->_add_file($filename) if( -f $filename || -l $filename);
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
# of the filename. This gives this Lane a chance to edit the filenames that are
# used, so that they can be specialised to assembly data.
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

  my $new_dst = file( $dst_path->dir, $id_dir . '.' . $prefix . '_' . $assembler . '.fa' );

  return ( $src_path, $new_dst );
}

#-------------------------------------------------------------------------------
#- builders --------------------------------------------------------------------
#-------------------------------------------------------------------------------

# build an array of headers for the statistics report
#
# required by the Stats Role

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
#
# required by the Stats Role

sub _build_stats {
  my $self = shift;

  my @rows;
  foreach my $assembler ( @{ $self->assemblers } ) {

    # see if this lane has an assembly created by this assembler
    my $assembly_dir = dir( $self->symlink_path, "${assembler}_assembly" );
    next unless -d $assembly_dir;

    # stash the row of statistics for each of the assemblies created by the
    # current assembler
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

sub _get_stats_row {
  my ( $self, $assembler, $assembly_file ) = @_;

  # shortcut to a hash containing Bio::Track::Schema::Result objects
  my $t = $self->_tables;

  my $assembly_dir   = dir( $self->symlink_path, "${assembler}_assembly" );

  my $stats_file     = file( $assembly_dir, $assembly_file );
  return [$self->row->name, $self->_get_assembly_type($assembly_dir, $assembly_file) || 'NA'] unless(-e $stats_file && -s $stats_file);
  my $file_stats     = $self->_parse_stats_file($stats_file);

  my $bamcheck_file  = file( $assembly_dir, 'contigs.mapped.sorted.bam.bc' );
  return [$self->row->name, $self->_get_assembly_type($assembly_dir, $assembly_file) || 'NA'] unless(-e $bamcheck_file && -s $bamcheck_file);
  my $bamcheck_stats = $self->_parse_bc_file($bamcheck_file);

  return [
    $self->row->name,
    $self->_get_assembly_type($assembly_dir, $assembly_file) || 'NA', # not sure if it's ever undef...
    $file_stats->{total_length},
    $file_stats->{num_contigs},
    $file_stats->{average_contig_length},
    $file_stats->{largest_contig},
    $file_stats->{N50},
    $file_stats->{N50_n},
    $file_stats->{N60},
    $file_stats->{N60_n},
    $file_stats->{N70},
    $file_stats->{N70_n},
    $file_stats->{N80},
    $file_stats->{N80_n},
    $file_stats->{N90},
    $file_stats->{N90_n},
    $file_stats->{N100},
    $file_stats->{N100_n},
    $file_stats->{n_count},
    $bamcheck_stats->{sequences},
    $bamcheck_stats->{'reads mapped'},
    $bamcheck_stats->{'reads unmapped'},
    $bamcheck_stats->{'reads paired'},
    $bamcheck_stats->{'reads unpaired'},
    $bamcheck_stats->{'total length'},
    $bamcheck_stats->{'bases mapped'},
    $bamcheck_stats->{'bases mapped (cigar)'},
    $bamcheck_stats->{'average length'},
    $bamcheck_stats->{'maximum length'},
    $bamcheck_stats->{'average quality'},
    $bamcheck_stats->{'insert size average'},
    $bamcheck_stats->{'insert size standard deviation'},
  ];
}

#-------------------------------------------------------------------------------

1;

