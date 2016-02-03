
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

use Bio::Path::Find::Types qw( :types );

extends 'Bio::Path::Find::Lane';

with 'Bio::Path::Find::Lane::Role::Stats';

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
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
  is      => 'rw',
  isa     => ArrayRef[Assembler],
  lazy    => 1,
  builder => '_build_assemblers',
);

sub _build_assemblers {
  return [ qw(
    velvet
    spades
    iva
    pacbio
  ) ];
}

# TODO ideally we need to get this list from the Types library. It's daft
# TODO having it in two places

# TODO or we could get it from the config, but that would mean passing in the
# TODO config hash when we instantiate the Lane, which would have to be done
# TODO in the B::P::F::Finder::find_lanes method

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

#---------------------------------------

# make the "filetype" attribute require values of type AssemblyType. This is to
# make sure that this class correctly restrict the sorts of files that it will
# return.

has '+filetype' => (
  isa => Maybe[AssemblyType],
);

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
#- methods for file finding ----------------------------------------------------
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

sub _get_stats_row {
  my ( $self, $assembler, $assembly_file ) = @_;

  # shortcut to a hash containing Bio::Track::Schema::Result objects
  my $t = $self->_tables;

  my $assembly_dir   = dir( $self->symlink_path, "${assembler}_assembly" );

  my $stats_file     = file( $assembly_dir, $assembly_file );
  my $file_stats     = $self->_parse_stats_file($stats_file);

  my $bamcheck_file  = file( $assembly_dir, 'contigs.mapped.sorted.bam.bc' );
  my $bamcheck_stats = $self->_parse_bc_file($bamcheck_file);

  return [
    $t->{lane}->name,
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

