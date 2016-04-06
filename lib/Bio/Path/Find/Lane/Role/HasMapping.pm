
package Bio::Path::Find::Lane::Role::HasMapping;

# ABSTRACT: a role that provides functionality related to mappings

use v5.10; # for "say"

use Moose::Role;

use Path::Class;

use Types::Standard qw(
  ArrayRef
  HashRef
  Str
);

use Bio::Path::Find::Types qw( :all );

with 'Bio::Path::Find::Role::HasConfig';

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

sub _get_files {
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

    my @files = $self->_generate_filenames(
      $mapstats_id,
      $pairing,
      $filetype,
      @additional_args,
    );

    FILE: foreach my $file ( @files ) {

      # prepend the lane's directroy path
      my $symlink_path = file($self->symlink_path, $file)->cleanup;
      # NOTE: for some reason, we need to clean up the path that we're
      # generating here, in order to remove an empty directory layer that gets
      # added when we combine the symlink directory path and the relative file
      # path. It could, just maybe, be a bug in Path::Class...

      # store the file and the extra information for the file
      $self->_add_file($symlink_path);
      $self->_verbose_file_info->{$symlink_path} = [
        $lane_reference,          # name of the reference
        $lane_mapper,             # name of the mapper
        $mapstats_row->changed,   # last update timestamp
      ];
    }

  } # end of "MAPPING" foreach
}

#-------------------------------------------------------------------------------

1;

