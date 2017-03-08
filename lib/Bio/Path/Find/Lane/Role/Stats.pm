
package Bio::Path::Find::Lane::Role::Stats;

# ABSTRACT: a role that provides methods for retrieving and formatting statistics about lanes

use Moose::Role;

use Path::Class;

use Types::Standard qw(
  ArrayRef
  HashRef
  Str
  Int
  Bool
  +Num
);

use Bio::Path::Find::Types qw(
  BioTrackSchemaResultBase
);

requires '_build_stats_headers',
         '_build_stats';

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=attr headers

Reference to an array containing column headers for stats output.

=cut

has 'stats_headers' => (
  is      => 'ro',
  isa     => ArrayRef[Str],
  lazy    => 1,
  builder => '_build_stats_headers',
);

#---------------------------------------

=attr stats

Reference to an array containing stats. Column order is the same as in
L<headers>.

=cut

has 'stats' => (
  is      => 'ro',
  isa     => ArrayRef[ArrayRef],
  lazy    => 1,
  builder => '_build_stats',
);

#---------------------------------------

=attr use_qc_stats

Specify that the mapping stats should be taken from QC, rather than mapping.
Default false, i.e. mapping statistics will be taken from the row in the
C<mapstats> table where C<is_qc == 0>.

=cut

has 'use_qc_stats' => (
  is      => 'rw',
  isa     => Bool,
  default => 0,
);

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

has '_mapstats_rows' => (
  is      => 'ro',
  isa     => ArrayRef[BioTrackSchemaResultBase],
  lazy    => 1,
  builder => '_build_mapstats',
  traits  => ['Array'],
  handles => {
    _all_mapstats_rows    => 'elements',
    _has_mapstats_rows    => 'count',
    _has_no_mapstats_rows => 'is_empty',
  },
  clearer => '_clear_mapstats_rows',
);

sub _build_mapstats {
  my $self = shift;

  my $mapstats_rs = $self->row->search_related(
    'latest_mapstats',
    { is_qc => $self->use_qc_stats },
  );

  return [ $mapstats_rs->all ];
}

#-------------------------------------------------------------------------------

# a hash ref with table name as key and the Bio::Track::Schema::Result for that
# table as the value. Essentially just a shortcut to having to write out the
# full chain of relationships everywhere.

has '_tables' => (
  is      => 'ro',
  isa     => HashRef[BioTrackSchemaResultBase],
  lazy    => 1,
  builder => '_build_tables',
);

sub _build_tables {
  my $self = shift;

  my $t = {};

  $t->{library}  = $self->row->latest_library;
  $t->{sample}   = $self->row->latest_library->latest_sample;
  $t->{project}  = $self->row->latest_library->latest_sample->latest_project;

  return $t;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# these are all methods that return specific fields

#-------------------------------------------------------------------------------

sub _mapped_percentage {
  my ( $self, $mapstats_row ) = @_;

  $mapstats_row ||= $self->_tables->{mapstats};

  return '0.0' unless $self->_mapping_is_complete($mapstats_row);
  return $self->_percentage( $mapstats_row->reads_mapped,
                             $mapstats_row->raw_reads );
}

#-------------------------------------------------------------------------------

sub _paired_percentage {
  my ( $self, $mapstats_row ) = @_;

  $mapstats_row ||= $self->_tables->{mapstats};

  return '0.0' unless $self->_mapping_is_complete($mapstats_row);
  return $self->_percentage( $mapstats_row->reads_paired,
                             $mapstats_row->raw_reads );
}


#-------------------------------------------------------------------------------

sub _map_type {
  my ( $self, $mapstats_row ) = @_;

  return 'NA' if not defined $mapstats_row;
  return $mapstats_row->is_qc ? 'QC' : 'Mapping';
}

#-------------------------------------------------------------------------------

# this algorithm is (hopefully) an exact reproduction of the original one
# (see old Path::Find::Stats::Row, line 582)

sub _depth_of_coverage {
  my ( $self, $mapstats_row ) = @_;

  return 'NA' if not defined $mapstats_row;

  # start with the value from the mapstats row, if there is one
  my $depth = $mapstats_row->mean_target_coverage;

  # if this is a QC mapping, try to calculate the depth of coverage for it
  if ( $mapstats_row->is_qc and $self->_mapping_is_complete($mapstats_row) ) {

    my $rmdup_bases_mapped = $mapstats_row->rmdup_bases_mapped;
    my $genome_size        = $mapstats_row->assembly->reference_size;

    # if we know the genome size, and if we don't already have a value for
    # it, calculate the coverage depth
    if ( $genome_size and not defined $depth ) {
      $depth = $rmdup_bases_mapped / $genome_size;
    }

    # scale by lane bases / sample bases
    my $qc_bases = $mapstats_row->raw_bases;
    my $bases    = $self->row->raw_bases;

    $depth = ( $depth * $bases ) / $qc_bases;
  }
  elsif(defined($depth) && $depth >= 0)
  {
  	return $self->_trimf( $depth );
  }
  else
  {
	return 'NA';
  }

  # tidy up the value and return it
  return $self->_trimf( $depth );
}

#-------------------------------------------------------------------------------

# (see old Path::Find::Stats::Row, line 611)

sub _depth_of_coverage_sd {
  my ( $self, $mapstats_row ) = @_;

  return 'NA' if not defined $mapstats_row;

  # get the value directly from the mapstats table
  my $depth_sd = $mapstats_row->target_coverage_sd;
  return 'NA' if not defined $depth_sd;

  # if this is a QC mapping, scale it
  if ( $mapstats_row->is_qc and $self->_mapping_is_complete($mapstats_row) ) {

    my $qc_bases = $mapstats_row->raw_bases;
    my $bases    = $self->row->raw_bases;
    return 'NA' if not defined $qc_bases;
    return 'NA' if not defined $bases;

    $depth_sd = ( $depth_sd * $bases ) / $qc_bases;
  }
  elsif(defined($depth_sd) && $depth_sd >= 0)
  {
  	return $self->_trimf( $depth_sd );
  }
  else
  {
	return 'NA';
  }

  return $self->_trimf( $depth_sd );
}

#-------------------------------------------------------------------------------

sub _adapter_percentage {
  my ( $self, $ms ) = @_;

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
  my ( $self, $ms ) = @_;

  return 'NA' unless ( defined $ms and
                       $ms->is_qc  and
                       $ms->percentage_reads_with_transposon );

  return $self->_trimf( $ms->percentage_reads_with_transposon, '%.1f' );
}

#-------------------------------------------------------------------------------

sub _genome_covered {
  my ( $self, $ms ) = @_;

  return 'NA' unless ( defined $ms and
                       $ms->is_qc  and
                       $self->_mapping_is_complete($ms) );

  my $target_bases_mapped = $ms->target_bases_mapped;
  my $genome_size         = $ms->assembly->reference_size;

  return 'NA' unless ( $target_bases_mapped and
                       $genome_size );

  return $self->_percentage( $target_bases_mapped, $genome_size, '%5.2f' );
}

#-------------------------------------------------------------------------------

sub _duplication_rate {
  my ( $self, $ms ) = @_;

  return 'NA' unless ( defined $ms and
                       $ms->is_qc  and
                       $self->_mapping_is_complete($ms) );

  my $rmdup_reads_mapped = $ms->rmdup_reads_mapped;
  my $reads_mapped       = $ms->reads_mapped;

  return 'NA' unless ( $rmdup_reads_mapped and
                       $reads_mapped );

  $self->_trimf( 1 - ( $rmdup_reads_mapped / $reads_mapped ), '%.4f' );
}

#-------------------------------------------------------------------------------

sub _error_rate {
  my ( $self, $ms ) = @_;

  return 'NA' unless ( defined $ms and
                       $ms->is_qc  and
                       $self->_mapping_is_complete($ms) );

  return $self->_trimf( $ms->error_rate, '%.3f' );
}

#-------------------------------------------------------------------------------

sub _het_snp_stats {
  my $self = shift;

  my $report_file = file(
    $self->symlink_path,
    'qc-sample',
    $self->row->hierarchy_name . '_heterozygous_snps_report.txt'
  );

  return qw( NA NA NA NA ) unless -f $report_file;

  my @lines = $report_file->slurp(chomp => 1);

  return split m/\t/, $lines[1];
}

#-------------------------------------------------------------------------------
#- utility methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# these are all utility methods, which format, edit or tidy parameters, rather
# than retrieving or generating fields

# TODO properly validate the parameters that are passed into all of these
# TODO methods. Use Type::Tiny to check

#-------------------------------------------------------------------------------

# returns the input string trimmed of whitespace at start and end

sub _trim {
  my ( $self, $string ) = @_;
  return unless defined $string;
  $string =~ s/^\s+|\s+$//g;
  return $string;
}

#-------------------------------------------------------------------------------

# returns the input string trimmed of whitespace and formatted according to the
# supplied sprintf format. Default format is '%.2f' if omitted.

sub _trimf {
  my ( $self, $string, $format ) = @_;

  $format ||= '%.2f';
  return is_Num($string)
         ? sprintf( $format, $self->_trim($string) )
         : $self->_trim($string);
}

#-------------------------------------------------------------------------------

# returns true if the lane has mapstats and the "bases_mapped" flag is true

sub _mapping_is_complete {
  my ( $self, $mapstats_row ) = @_;
  return undef if not defined $mapstats_row;
  return $mapstats_row->bases_mapped ? 1 : 0;
}

#-------------------------------------------------------------------------------

# given two values, $a and $b, returns $a as a percentage of $b, formatted
# according to the supplied sprintf format. Default format is '%.1f' if
# ommitted.

sub _percentage {
  my ( $self, $a, $b, $format ) = @_;
  return 'NaN' unless ( is_Num($a) and is_Num($b) );
  $format ||= '%.1f';
  return $self->_trim( sprintf $format, ( $a / $b ) * 100 );
}

#-------------------------------------------------------------------------------

1;

