
package Bio::Path::Find::Lane::Status;

# ABSTRACT: a class for working with status information about lanes

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Bio::Path::Find::Lane::StatusFile;

use Types::Standard qw(
  ArrayRef
  HashRef
  Str
  Int
);
use Bio::Path::Find::Types qw(
  BioPathFindLane
  BioPathFindLaneStatusFile
  PathClassFile
  Datetime
);

use Bio::Path::Find::Exception;

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

# required attributes

has 'lane' => (
  is       => 'ro',
  isa      => BioPathFindLane,
  required => 1,
);

#---------------------------------------

=attr status_files

Reference to a hash containing a pipeline name as the key and an arrayref as
the value. The array contains status file object(s)
(L<Bio::Path::Find::Lane::StatusFile>) for the named pipeline.

In most cases there will be only a single status file for each pipeline, but
some pipelines, e.g. mapping, may be run multiple times for a given sample,
hence there may be multiple status files present.

=cut

has 'status_files' => (
  traits  => ['Hash'],
  is      => 'ro',
  isa     => HashRef[ArrayRef[BioPathFindLaneStatusFile]],
  lazy    => 1,
  builder => '_build_status_files',
  handles => {
    all_status_files => 'values',
    has_status_files => 'count',
  },
);

sub _build_status_files {
  my $self = shift;

  my $files = {};

  foreach my $status_file ( grep m/_job_status$/, $self->lane->symlink_path->children ) {
    my $status_file_object = Bio::Path::Find::Lane::StatusFile->new( status_file => $status_file );
    push @{ $files->{ $status_file_object->pipeline_name } }, $status_file_object;
  }

  return $files;
}

#---------------------------------------

has 'processed_flags' => (
  is      => 'ro',
  isa     => HashRef[Int],
  default => sub {
    {
    # pipeline name         binary value
      import             => 1,
      qc                 => 2,
      mapped             => 4,
      stored             => 8,
      deleted            => 16,
      swapped            => 32,
      altered_fastq      => 64,
      improved           => 128,
      snp_called         => 256,
      rna_seq_expression => 512,
      assembled          => 1024,
      annotated          => 2048,
    };
  },
);

#-------------------------------------------------------------------------------
#- methods ---------------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 all_status_files

Returns a list of the L<Bio::Path::Find::Lane::StatusFile> objects for this lane.

=head2 has_status_files

Returns true if there are any available status file objects for this lane.
False otherwise.

=cut

#-------------------------------------------------------------------------------

=head2 pipeline_status($pipeline_name)

Returns the status of the specified pipeline. There are several possible
return values:

=over

=item NA

if the pipeline name is not recognised

=item Done

if the database shows that the specified pipeline is complete

=item -

if there is no status file for the specified pipeline for this lane

=item <status> . (<last status update date>)

if there is a status file for the specified pipeline

=back

=cut

sub pipeline_status {
  my ( $self, $pipeline_name ) = @_;

  return 'NA' if not defined $pipeline_name;

  my $bit_pattern = $self->lane->row->processed;
  my $bit_value   = $self->processed_flags->{$pipeline_name};

  # not a valid flag
  return 'NA' if not defined $bit_value;

  # if the specified flag is set in the "processed" bit pattern, that stage of
  # the pipeline is done
  return 'Done' if $bit_pattern & $bit_value;

  # bail unless:
  # 1. we found at least one pipeline status file, and
  # 2. it's a status file for the specified pipeline
  return '-' unless ( $self->has_status_files and
                      $self->status_files->{$pipeline_name} );

  my $status_file_objects = $self->status_files->{$pipeline_name};

  # sort on (descending) date of last update, so that we get status from the
  # most recently updated status file.
  # NOTE that we base this on the timestamp OF the statusfile, NOT the
  # NOTE timestamp IN the status file
  my @sorted_status_file_objects = sort { $b->last_update->epoch <=> $a->last_update->epoch }
                                        @$status_file_objects;

  my $latest_status_file_object = $sorted_status_file_objects[0];

  return ucfirst $latest_status_file_object->current_status
                 . ' (' . $latest_status_file_object->last_update->dmy . ')';
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

