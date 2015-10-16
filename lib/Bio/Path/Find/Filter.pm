
package Bio::Path::Find::Filter;

# ABSTRACT: class to filter sets of results from a path find search

use v5.10;

use Moose;
use namespace::autoclean;

use Path::Class;
use File::Find::Rule;
use Type::Params qw( compile );
use Types::Standard qw( Object slurpy Dict Optional ArrayRef HashRef Str Maybe Int );
use Bio::Path::Find::Types qw(
  BioTrackSchemaResultLatestLane
  QCState
  IDType
);

with 'Bio::Path::Find::Role::HasEnvironment',
     'Bio::Path::Find::Role::HasConfig';

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

Inherits C<config> and C<environment> from the roles
L<Bio::Path::Find::Role::HasConfig> and
L<Bio::Path::Find::Role::HasEnvironment>.

=attr filetype_extensions

Hash ref that maps a filetype, e.g. C<fastq>, to its file extension, e.g.
C<.fastq.gz>. The default mapping is:

  fastq     => '.fastq.gz',
  bam       => '.bam',
  pacbio    => '*.h5',
  corrected => '*.corrected.*'

=cut

# this mapping is cargo-culted from the original code and doesn't necessarily
# make much sense...

has 'filetype_extensions' => (
  is      => 'ro',
  isa     => HashRef[Str],
  default => sub {
    {
      fastq     => '.fastq.gz',
      bam       => '.bam',
      pacbio    => '*.h5',
      corrected => '*.corrected.*',
    };
  },
);

#---------------------------------------

=attr search_depth

The depth of the search when looking for files using a pattern match. Default
is 2 levels.

=cut

has 'search_depth' => (
  is      => 'rw',
  isa     => Int,
  default => 2,
);

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=cut

sub filter_lanes {
  state $check = compile(
    Object,
    slurpy Dict[
      lanes    => ArrayRef[BioTrackSchemaResultLatestLane], # array of lane objects
      qc       => Optional[Maybe[QCState]], # QC flag (passed, failed, pending)
      filetype => Optional[Maybe[Str]],     # the type of file (fastq, bam, pacbio)
    ],
  );
  my ( $self, $params ) = $check->(@_);

  LANE: foreach my $lane ( @{ $params->{lanes} } ) {

    # ignore this lane if:
    # 1. we've been told to look for a specific QC status, and
    # 2. the lane has a QC status set, and
    # 3. this lane's QC status doesn't match the required status
    next LANE if ( defined $params->{qc} and
                   defined $lane->qc_status and
                   $lane->qc_status ne $params->{qc} );

    # get a specific type of file
    if ( my $filetype = $params->{filetype} ) {
      my $files = $self->_find_files_for_lane( $lane, $filetype );
      next LANE unless scalar @files;

      FILE: foreach my $filepath ( @$files ) {
        next FILE if $filepath =~ m/pool_1.fastq.gz/;

      }
    }
    # get the path to all files
    else {

    }

    $DB::single = 1;

  }

  return $params->{lanes};
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

sub _find_files_for_lane {
  my ( $self, $lane, $filetype ) = @_;

  # root directory for files related to the database from which this lane data
  # were retrieved
  my $root_dir = $lane->database->hierarchy_root_dir;

  # the canonical path to the files for this lane
  my $storage_path = dir($root_dir, $lane->storage_path);

  # the symlinked path to the files for the lane
  my $symlink_path = dir($root_dir, $lane->path);

  my $extension = $self->filetype_extensions->{$filetype} if $filetype;

  if ( $filetype ) {
    return _get_fastqs($lane)    if $filetype eq 'fastq';
    return _get_corrected($lane) if $filetype eq 'corrected';
  }

  if ( $extension and $extension =~ m/\*/ ) {
    return File::Find::Rule->file
                           ->extras( { follow => 1 } )
                           ->maxdepth($self->search_depth)
                           ->name($extension)
                           ->in($symlink_path);
  }
}

#-------------------------------------------------------------------------------
#- functions -------------------------------------------------------------------
#-------------------------------------------------------------------------------

sub _get_fastqs {
  my $lane = shift;

  my $root_dir      = $lane->database->hierarchy_root_dir;
  my $database_name = $lane->database_name;

  my @found_files;
  while ( my $file = $lane->latest_files->next ) {
    my $filename = $file->name;

    # for illumina, the database stores the names of the fastq files directly.
    # For pacbio, however, the database stores the names of the bax files. Work
    # out the names of the fastq files from those bax filenames
    $filename =~ s/\d{1}\.ba[xs]\.h5$/fastq.gz/ if $database_name =~ m/pacbio/;

    my $filepath = file( $root_dir, $lane->path, $filename );
    push @found_files, $filepath if ( $filepath =~ m/fastq/ and -e $filepath );
  }

  return \@found_files
}

#-------------------------------------------------------------------------------

sub _get_corrected {
  my $lane = shift;

  my $root_dir = $lane->database->hierarchy_root_dir;
  my $filename = $lane->hierarchy_name . '.corrected.fastq.gz';
  my $filepath = file( $root_dir, $lane->path, $filename );

  return [ $filepath ] if -e $filepath;
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

