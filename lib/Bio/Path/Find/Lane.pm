
package Bio::Path::Find::Lane;

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw( carp );
use Path::Class;
use Types::Standard qw( Str Int HashRef ArrayRef );
use Bio::Path::Find::Types qw(
  BioTrackSchemaResultLatestLane
  PathClassFile
  PathClassDir
);

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

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
is 1 level.

=cut

has 'search_depth' => (
  is      => 'rw',
  isa     => Int,
  default => 1,
);

#---------------------------------------

=attr row

A L<Bio::Track::Schema::Result::LatestLane> object for this row.

=cut

has 'row' => (
  is  => 'ro',
  isa => BioTrackSchemaResultLatestLane,
);

#---------------------------------------

=attr files

Reference to an array of L<Path::Class::File> objects representing the files
associated with this lane.

=cut

has 'files' => (
  traits  => ['Array'],
  is      => 'rw',
  isa     => ArrayRef[PathClassFile],
  default => sub { [] },
  handles => {
    add_file     => 'push',
    all_files    => 'elements',
    has_files    => 'count',
    has_no_files => 'is_empty',
    file_count   => 'count',
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
  carp 'WARNING: no lane assigned; add a Bio::Track::Schema::Result::LatestLane first'
    unless defined $self->row;
  return dir( $self->row->database->hierarchy_root_dir );
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

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

sub find_files {
  my ( $self, $filetype ) = @_;

  my $extension = $self->filetype_extensions->{$filetype} if $filetype;

  if ( $filetype ) {
    if ( $filetype eq 'fastq' ) {
      $self->_get_fastqs;
    }
    elsif ( $filetype eq 'corrected' ) {
      $self->_get_corrected;
    }
  }
  elsif ( $extension ) {
    $self->_get_extension($extension) if $extension =~ m/\*/;
  }

}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

sub _get_fastqs {
  my $self = shift;

  # we have to save a reference the list of files for each lane Result,
  # otherwise DBIC will continually return the first row of the ResultSet
  # (see https://metacpan.org/pod/DBIx::Class::ResultSet#next)
  my $files = $self->row->latest_files;

  my @found_files;
  while ( my $file = $files->next ) {
    my $filename = $file->name;

    # for illumina, the database stores the names of the fastq files directly.
    # For pacbio, however, the database stores the names of the bax files. Work
    # out the names of the fastq files from those bax filenames
    $filename =~ s/\d{1}\.ba[xs]\.h5$/fastq.gz/
      if $self->row->database_name =~ m/pacbio/;

    my $filepath = file( $self->symlink_path, $filename );

    if ( $filepath =~ m/fastq/ and
         $filepath !~ m/pool_1.fastq.gz/ and
         -e $filepath ) {
      $self->add_file($filepath);
    }

    # TODO set up some test data: copy the files associated with the lanes
    # TODO that we're looking for, putting them into t/data/06_finder/root_dir

    $DB::single = 1;
  }
}

#-------------------------------------------------------------------------------

sub _get_corrected {
  my $self = shift;

  my $filename = $self->hierarchy_name . '.corrected.fastq.gz';
  my $filepath = file( $self->symlink_path, $filename );

  $self->add_file($filepath) if -e $filepath;
}

#-------------------------------------------------------------------------------

sub _get_extension {
  my ( $self, $extension ) = @_;

  my @files = File::Find::Rule->file
                              ->in($self->symlink_path)
                              ->name($extension)
                              ->maxdepth($self->search_depth)
                              ->extras( { follow => 1 } );

  $self->add_file($_) for @files;
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

