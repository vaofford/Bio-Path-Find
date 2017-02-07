
package Bio::Path::Find::Lane::Role::HasMapping;

# ABSTRACT: a role that provides functionality related to mappings

use v5.10; # for "say"

use MooseX::App::Role;

use Path::Class;
use File::stat;
use DateTime;
use Types::Standard qw(
  ArrayRef
  HashRef
  Str
  Bool
);

use Bio::Path::Find::Types qw( :types );

with 'Bio::Path::Find::Role::HasConfig',
     'Bio::Path::Find::Lane::Role::Stats';

requires '_generate_filenames';

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

=attr mappers

A list of names of mapping software that the mapping-related code understands.
The list is taken from L<type library|Bio::Path::Find::Types>, currently:

=over

=item bowtie2

=item bwa

=item bwa_aln

=item smalt

=item ssaha2

=item stampy

=item tophat

=back

=cut

has 'mappers' => (
  is      => 'ro',
  isa     => Mappers,
  lazy    => 1,
  builder => '_build_mappers',
);

sub _build_mappers {
  return Mapper->values;
}

#---------------------------------------

=attr reference

The name of the reference genome on which to filter returned lanes.

=cut

has 'reference' => (
  is  => 'ro',
  isa => Str,
);

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# somewhere to store extra information about the files that we find. The info
# is stored as hashref, keyed on the file path.

has '_verbose_file_info' => (
  is      => 'rw',
  isa     => HashRef[ArrayRef[Str]],
  default => sub { {} },
);

#-------------------------------------------------------------------------------
#- builders --------------------------------------------------------------------
#-------------------------------------------------------------------------------

# build an array of headers for the statistics display
#
# required by the Stats Role

sub _build_stats_headers {
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
    'Genome Covered (% >= 1X)',
    'Genome Covered (% >= 5X)',
    'Genome Covered (% >= 10X)',
    'Genome Covered (% >= 50X)',
    'Genome Covered (% >= 100X)'
  ];
}

#-------------------------------------------------------------------------------

# collect together the fields for the statistics report
#
# required by the Stats Role

sub _build_stats {
  my $self = shift;

  # for each mapstats row for this lane, get a row of statistics, filtered by reference, as an
  # arrayref, and push it into the return array.
  
  my @stats;
  for my $stats_row ($self->_all_mapstats_rows){ 
    if(defined($self->reference))
    {
      if( $stats_row->assembly->name eq $self->reference) {
        push(@stats, $self->_get_stats_row($stats_row));
      }
    }
    else {
      push(@stats, $self->_get_stats_row($stats_row));
    }
  }
  
  return \@stats;
}

#-------------------------------------------------------------------------------
#- methods ---------------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 print_details

For each file found by this lane, print:

=over

=item the path to the file itself

=item the reference to which reads were mapped

=item the name of the mapping software used

=item the date at which the mapping was generated

=back

The items are printed as a simple tab-separated list, one row per file.

=cut

sub print_details {
  my $self = shift;

  foreach my $file ( $self->all_files ) {
    say join "\t", $file, @{ $self->_verbose_file_info->{$file} };
  }
}

#-------------------------------------------------------------------------------

=head2 get_file_info($file)

Returns a reference to an array containing the details of the specified file.
The file should be the L<Path::Class::File> object that's returned by a call
to C<$lane-E<gt>all_files>. The returned array contains the following fields:

=over

=item reference

The name of the reference genome that was used during mapping

=item mapper

The name of the mapping program

=item timestamp

The time/date at which the mapping was generated

=cut

sub get_file_info {
  my ( $self, $file ) = @_;
  return $self->_verbose_file_info->{$file};
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

sub _get_mapping_files {
  my ( $self, $filetype, @additional_args ) = @_;

  my $lane_row = $self->row;

  my $mapstats_rows = $lane_row->search_related_rs( 'latest_mapstats', { is_qc => 0 } );

  # if there are no rows for this lane in the mapstats table, it hasn't had
  # mapping run on it, so we're done here
  return unless $mapstats_rows->count;

  MAPPING: foreach my $mapstats_row ( $mapstats_rows->all ) {

    my $mapstats_id = $mapstats_row->mapstats_id;
    my $prefix      = $mapstats_row->prefix;

    # single or paired end ?
    my $pairing = $lane_row->paired ? 'pe' : 'se';

    # find the path (on NFS) to the job status file for this mapping run
    my $job_status_file = file( $lane_row->storage_path, "${prefix}job_status" );

    # if the job failed or is still running, the file "<prefix>job_status" will
    # still exist, in which case we don't want to return *any* bam files
    next MAPPING if -f $job_status_file;

    # at this point there's no job status file, so the mapping job is done

    #---------------------------------------

    # apply filters

    # this is the mapper that was actually used to map this lane's reads
    my $lane_mapper = $mapstats_row->mapper->name;

    # this is the reference that was used for this particular mapping
    my $lane_reference = $mapstats_row->assembly->name;

    # return only mappings generated using a specific mapper
    if ( $self->mappers ) {
      # the user provided a list of mappers. Convert it into a hash so that
      # we can quickly look up the lane's mapper in there
      my %wanted_mappers = map { $_ => 1 } @{ $self->mappers };

      # unless the lane's mapper is one of the mappers that the user specified,
      # skip this mapping
      next MAPPING unless exists $wanted_mappers{$lane_mapper};
    }

    # return only mappings that use a specific reference genome
    next MAPPING if ( $self->reference and $lane_reference ne $self->reference );

    #---------------------------------------

    # build the name of the file(s) for this mapping. This is a call to the
    # concrete class. The "_generate_filenames" method should build a list of
    # filenames for this lane. They should be relative to the base directory
    # of the lane, and we'll add on the symlink path before storing, so that
    # the lane always returns paths in its symlink directory.

    my $files = $self->_generate_filenames(
      $mapstats_id,
      $pairing,
      $filetype,
      @additional_args,
    );

    foreach my $file ( @$files ) {
      next unless(-e $file);
      # store the file and the extra information for the file
      $self->_add_file($file);
      $self->_verbose_file_info->{$file} = [
        $lane_reference,          # name of the reference
        $lane_mapper,             # name of the mapper
        _file_time_stamp($file),  # file modification time
      ];
    }

  } # end of "MAPPING" foreach
}

#-------------------------------------------------------------------------------

# Lookup the timestamp of a file and format it in the same way as in the Database
sub _file_time_stamp
{
  my ( $file ) = @_;
  my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime( stat($file)->mtime );
  return DateTime->new( year => $year+1900, month => $mon +1, day => $mday, hour => $hour, minute => $min, second => $sec);
}

# build a row of statistics for the current lane and specified mapstats row

sub _get_stats_row {
  my ( $self, $ms ) = @_;

  # shortcut to a hash containing Bio::Track::Schema::Result objects
  my $t = $self->_tables;

  return [
    $t->{project}->ssid,
    $t->{sample}->name,
    $self->row->name,
    $self->row->readlen,
    $self->row->raw_reads,
    $self->row->raw_bases,
    $self->_map_type($ms),
    defined $ms ? $ms->assembly->name           : undef,
    defined $ms ? $ms->assembly->reference_size : undef,
    defined $ms ? $ms->mapper->name             : undef,
    defined $ms ? $ms->mapstats_id              : undef,
    $self->_mapped_percentage($ms),
    $self->_paired_percentage($ms),
    defined $ms ? $ms->mean_insert              : undef,
    $self->_depth_of_coverage($ms),
    $self->_depth_of_coverage_sd($ms),
    defined $ms && $ms->target_bases_1x   ? sprintf( '%.1f', $ms->target_bases_1x   ) : undef,
    defined $ms && $ms->target_bases_5x   ? sprintf( '%.1f', $ms->target_bases_5x   ) : undef,
    defined $ms && $ms->target_bases_10x  ? sprintf( '%.1f', $ms->target_bases_10x  ) : undef,
    defined $ms && $ms->target_bases_50x  ? sprintf( '%.1f', $ms->target_bases_50x  ) : undef,
    defined $ms && $ms->target_bases_100x ? sprintf( '%.1f', $ms->target_bases_100x ) : undef,
  ];
}

#-------------------------------------------------------------------------------

1;

