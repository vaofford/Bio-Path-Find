
package Bio::Path::Find::Lane;

# ABSTRACT: a class for working with information about a sequencing lane

use v5.10; # required for Type::Params use of "state"

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw( carp croak );
use Path::Class;
use File::Find::Rule;

use Bio::Path::Find::LaneStatus;

use Type::Params qw( compile );
use Types::Standard qw( Object Str Int HashRef ArrayRef );
use Bio::Path::Find::Types qw(
  BioPathFindLaneStatus
  BioTrackSchemaResultLatestLane
  PathClassFile
  PathClassDir
);

with 'MooseX::Log::Log4perl',
     'MooseX::Traits';

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------
#- attributes ------------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

=cut

#-------------------------------------------------------------------------------
#- required attributes ---------------------------------------------------------
#-------------------------------------------------------------------------------

=attr row

A L<Bio::Track::Schema::Result::LatestLane> object for this row.

=cut

has 'row' => (
  is       => 'ro',
  isa      => BioTrackSchemaResultLatestLane,
  required => 1,
);

#-------------------------------------------------------------------------------
#- optional read-write attributes ----------------------------------------------
#-------------------------------------------------------------------------------

=attr filetype_extensions

Hash ref that maps a filetype, e.g. C<fastq>, to its file extension, e.g.
C<.fastq.gz>. The default mapping is:

  fastq     => '.fastq.gz',
  bam       => '*.bam',
  pacbio    => '*.h5',
  corrected => '*.corrected.*'

=cut

# this mapping is cargo-culted from the original code and doesn't necessarily
# make much sense...

has 'filetype_extensions' => (
  is      => 'rw',
  isa     => HashRef[Str],
  default => sub {
    {
      fastq     => '.fastq.gz',
      bam       => '*.bam', # NOTE no wildcard in mapping in original PathFind
      pacbio    => '*.h5',
      corrected => '*.corrected.*',
    };
  },
);

#---------------------------------------

=attr search_depth

The depth of the search when looking for files using a pattern match. Default
is 1 level.

=cut

has 'search_depth' => (
  is      => 'rw',
  isa     => Int,
  default => 1,
);

#-------------------------------------------------------------------------------
#- read-only attributes --------------------------------------------------------
#-------------------------------------------------------------------------------

=attr files

Reference to an array of L<Path::Class::File> objects representing the files
associated with this lane.

=cut

# this is a read-write attribute but it's only writeable via a private
# accessor

has 'files' => (
  traits  => ['Array'],
  is      => 'ro',
  isa     => ArrayRef[PathClassFile],
  default => sub { [] },
  handles => {
    _add_file    => 'push',      # private method
    all_files    => 'elements',
    has_files    => 'count',
    has_no_files => 'is_empty',
    file_count   => 'count',
    clear_files  => 'clear',
  },
);

#---------------------------------------

=attr root_dir

A L<Path::Class::Dir> object representing the root directory for files related
to the database from which this lane was derived.

=cut

has 'root_dir' => (
  is      => 'ro',
  isa     => PathClassDir,
  lazy    => 1,
  builder => '_build_root_dir',
);

sub _build_root_dir {
  my $self = shift;

  my $root_dir = dir( $self->row->database->hierarchy_root_dir );

  # sanity check: make sure that the root directory, the top of the filesystem
  # tree for all of the files that we're going to look for, actually exists. If
  # it doesn't, that might indicate a problem with the mountpoint on the
  # machine and it's worth telling the user, so that they don't simply think
  # their IDs etc. don't exist
  croak "ERROR: can't see the filesystem root ($root_dir). This may indicate a problem with mountpoints"
    unless -e $root_dir;

  return $root_dir;
}

#---------------------------------------

=attr storage_path

A L<Path::Class::Dir> object representing the canonical path to all files for
this lane.

=cut

has 'storage_path' => (
  is      => 'ro',
  isa     => PathClassDir,
  lazy    => 1,
  builder => '_build_storage_path',
);

sub _build_storage_path {
  my $self = shift;
  return dir( $self->root_dir, $self->row->storage_path );
}

#---------------------------------------

=attr symlink_path

A L<Path::Class::Dir> object representing the symlinked directory for file
related to this lane.

=cut

has 'symlink_path' => (
  is      => 'ro',
  isa     => PathClassDir,
  lazy    => 1,
  builder => '_build_symlink_path',
);

sub _build_symlink_path {
  my $self = shift;
  return dir( $self->root_dir, $self->row->path );
}

#---------------------------------------

=attr found_file_type

The type of file that was found when running L<find_files>, or C<undef> if
L<find_files> has not yet been run. This is specified as an argument to
L<find_files> and cannot be set separately. B<Read only>.

=cut

has 'found_file_type' => (
  is     => 'rw',
  isa    => Str,
  writer => '_set_found_file_type',
);

#---------------------------------------

=attr status

The L<Bio::Path::Find::LaneStatus> object for this lane.

=cut

has 'status' => (
  is      => 'ro',
  isa     => BioPathFindLaneStatus,
  lazy    => 1,
  builder => '_build_status',
  handles => [
    'pipeline_status',
  ],
);

sub _build_status {
  my $self = shift;

  return Bio::Path::Find::LaneStatus->new( lane => $self );
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=cut

# these methods are all generated by the traits on attributes

=head2 all_files

Returns a list of the files for this lane. The files are represented by
L<Path::Class::File> objects, giving the absolute path to the file on disk.

=head2 has_files

Returns true if this lane has files associated with it, false otherwise.
B<Note> that this method will return false if the L<find_files> method has
been run but there are no files found, and also if the L<find_files> method
simply hasn't yet been run.

=head2 has_no_files

Returns true if this file has B<no> files associated with it, true otherwise.
To be explicit, this is the inverse of L<has_files>.

=head2 file_count

Returns the number of files associated with this lane.

=head2 clear_files

Clears the list of found files. No return value.

=cut

#-------------------------------------------------------------------------------

# these are concrete methods from this class

=head2 find_files($filetype)

Look for files associated with this lane with a given filetype. Returns the
number of files found.

=cut

sub find_files {
  state $check = compile( Object, Str );
  my ( $self, $filetype ) = $check->(@_);

  $self->_set_found_file_type($filetype);

  $self->clear_files;

  if ( $filetype eq 'fastq' ) {
    $self->_get_fastqs;
  }
  elsif ( $filetype eq 'corrected' ) {
    $self->_get_corrected;
  }

  if ( $self->has_no_files ) {
    my $extension = $self->filetype_extensions->{$filetype};
    $self->_get_extension($extension)
      if ( defined $extension and $extension =~ m/\*/ );
  }

  return $self->file_count;
}

#-------------------------------------------------------------------------------

=head2 print_paths

Prints the paths for this lane.

If a file type was specified when running L<find_files>, this method prints the
path to that type of file only. If file type was not specified, this method
prints the path to the directory containing all files for this lane.

Returns the number of files found, if a file type was specified, or 1 if we're
printing the path to the lane's directory.

=cut

sub print_paths {
  my $self = shift;

  my $rv = 0;
  if ( $self->found_file_type ) {
    say $_ for ( $self->all_files );
    $rv += $self->has_files;
  }
  else {
    say $self->symlink_path;
    $rv = 1;
  }

  return $rv;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

sub _get_fastqs {
  my $self = shift;

  $self->log->trace('looking for fastq files');

  # we have to save a reference to the "latest_files" relationship for each
  # lane before iterating over it, otherwise DBIC will continually return the
  # first row of the ResultSet
  # (see https://metacpan.org/pod/DBIx::Class::ResultSet#next)
  my $files = $self->row->latest_files;

  FILE: while ( my $file = $files->next ) {
    my $filename = $file->name;

    # for illumina, the database stores the names of the fastq files directly.
    # For pacbio, however, the database stores the names of the bax files. Work
    # out the names of the fastq files from those bax filenames
    $filename =~ s/\d{1}\.ba[xs]\.h5$/fastq.gz/
      if $self->row->database->name =~ m/pacbio/;

    my $filepath = file( $self->symlink_path, $filename );

    if ( $filepath =~ m/fastq/ and
         $filepath !~ m/pool_1.fastq.gz/ ) {

      # the filename here is obtained from the database, so the file really
      # should exist on disk. If it doesn't exist, if the symlink in the root
      # directory tree is broken, we'll show a warning, because that indicates
      # a fairly serious mismatch between the two halves of the tracking system
      # (database and filesystem)
      unless ( -e $filepath ) {
        carp "ERROR: database says that '$filepath' should exist but it doesn't";
        next FILE;
      }

      $self->_add_file($filepath);
    }
  }
}

#-------------------------------------------------------------------------------

sub _get_corrected {
  my $self = shift;

  $self->log->trace('looking for "corrected" files');

  my $filename = $self->row->hierarchy_name . '.corrected.fastq.gz';
  my $filepath = file( $self->symlink_path, $filename );

  $self->_add_file($filepath) if -e $filepath;
}

#-------------------------------------------------------------------------------

sub _get_extension {
  my ( $self, $extension ) = @_;

  $self->log->trace(qq(searching for files with extension "$extension"));

  my @files = File::Find::Rule->file
                              ->extras( { follow => 1 } )
                              ->maxdepth($self->search_depth)
                              ->name($extension)
                              ->in($self->symlink_path);

  $self->log->debug('trace ' . scalar @files . ' files');

  $self->_add_file( file($_) ) for @files;
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

