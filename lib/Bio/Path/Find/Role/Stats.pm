
package Bio::Path::Find::Role::Stats;

use Moose::Role;

use Carp qw( croak );
use Types::Standard qw(
  ArrayRef
  HashRef
  Str
  Bool
);

use Bio::Path::Find::Types qw(
  BioTrackSchemaResultBase
);

requires '_build_headers', '_build_stats';

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=attr headers

Reference to an array containing column headers for stats output.

=cut

has 'headers' => (
  is      => 'ro',
  isa     => ArrayRef[Str],
  lazy    => 1,
  builder => '_build_headers',
);

#---------------------------------------

=attr stats

Reference to an array containing stats. Column order is the same as in
L<headers>.

=cut

has 'stats' => (
  is      => 'ro',
  isa     => ArrayRef[Str],
  lazy    => 1,
  builder => '_build_stats',
);

#---------------------------------------

# specify that the stats should be taken from QC, rather than mapping. Default
# true

has 'use_qc_stats' => (
  is      => 'ro',
  isa     => Bool,
  default => 1,
);

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
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

  $t->{lane}     = $self->row;
  $t->{library}  = $self->row->latest_library;
  $t->{sample}   = $self->row->latest_library->latest_sample;
  $t->{project}  = $self->row->latest_library->latest_sample->latest_project;

  # there may be multiple rows in the mapstats table for each lane,
  # representing a QC versus full mappings. Get just one row, corresponding to
  # the "use_qc_stats" attribute
  my $mapstats_rs = $self->row->search_related(
    'latest_mapstats',
    { is_qc => $self->use_qc_stats },
  );

  my ( $assembly, $mapper );
  if ( defined $mapstats_rs ) {
    $t->{mapstats} = $mapstats_rs->single;
    $t->{assembly} = $t->{mapstats}->assembly;
    $t->{mapper}   = $t->{mapstats}->mapper;
  }

  return $t;
}

#-------------------------------------------------------------------------------
#- methods ---------------------------------------------------------------------
#-------------------------------------------------------------------------------

# methods that are used in several stats roles

# returns true if:
# 1. we have a mapstats row for this lane
# 2. the stats are for a QC mapping, and
# 3. the mapping is complete

sub _is_mapped {
  my $self = shift;

  return 1 if ( defined $self->_tables->{mapstats} and
                $self->_tables->{mapstats}->is_qc  and
                $self->_mapping_is_complete );
}

#-------------------------------------------------------------------------------

# returns the input string trimmed of whitespace at start and end

sub _trim {
  my ( $self, $string ) = @_;
  $string =~ s/^\s+|\s+$//g;
  return $string;
}

#-------------------------------------------------------------------------------

# returns the input string trimmed of whitespace and formatted according to the
# supplied sprintf format. Default format is '%.2f' if omitted.

sub _trimf {
  my ( $self, $string, $format ) = @_;
  $format ||= '%.2f';
  return $self->_trim( sprintf $format, $string );
}

#-------------------------------------------------------------------------------

# returns true if the lane has mapstats and the "bases_mapped" flag is true

sub _mapping_is_complete {
  my $self = shift;
  return undef if not defined $self->_tables->{mapstats};
  return $self->_tables->{mapstats}->bases_mapped ? 1 : 0;
}

#-------------------------------------------------------------------------------

# given two values, $a and $b, returns $a as a percentage of $b, formatted
# according to the supplied sprintf format. Default format is '%.1f' if
# ommitted.

sub _percentage {
  my ( $self, $a, $b, $format ) = @_;
  $format ||= '%.1f';
  return $self->_trim( sprintf $format, ( $a / $b ) * 100 );
}

#-------------------------------------------------------------------------------

1;

