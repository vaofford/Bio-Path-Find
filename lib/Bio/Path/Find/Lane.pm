
package Bio::Path::Find::Lane;

# ABSTRACT: a class for working with information about a sequencing lane

use v5.10; # required for Type::Params use of "state"

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw( carp );
use Path::Class;
use File::Find::Rule;
use Try::Tiny;
use Cwd;

use Bio::Path::Find::Lane::Status;
use Bio::Path::Find::Exception;

use Type::Params qw( compile );
use Types::Standard qw(
  Object
  Str
  Int
  HashRef
  ArrayRef
  slurpy
  Dict
  Optional
  Bool
  Maybe
);
use Bio::Path::Find::Types qw( :types );

with 'MooseX::Log::Log4perl',
     'MooseX::Traits',
     'Bio::Path::Find::Role::HasProgressBar';

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
C<.fastq.gz>. The default mapping is empty and should be overridden by a
mapping provided by a C<Role|Bio::Path::Find::Lane::Role> applied to the
C<Lane>.

=cut

# this mapping is cargo-culted from the original code and doesn't necessarily
# make much sense...

has 'filetype_extensions' => (
  is      => 'rw',
  isa     => HashRef[Str],
  lazy    => 1,
  builder => '_build_filetype_extensions',
);

sub _build_filetype_extensions {
  {
    # empty mapping; provided by sub-class, e.g. B::P::F::Lane::Class::Data
  };
}

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
  isa     => ArrayRef[PathClassFile|Str],
  default => sub { [] },
  writer  => '_set_files',
  handles => {
    _add_file    => 'push',       # private method
    all_files    => 'elements',
    has_files    => 'count',
    has_no_files => 'is_empty',
    file_count   => 'count',
    clear_files  => 'clear',
    get_file     => 'get',        # used in tests
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
  unless ( -e $root_dir ) {
    Bio::Path::Find::Exception->throw(
      msg => "ERROR: can't see the filesystem root ($root_dir). This may indicate a problem with mountpoints"
    );
  }

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
  return dir( $self->row->storage_path );
}

#---------------------------------------

=attr symlink_path

A L<Path::Class::Dir> object representing the symlinked directory for data
files related to this lane.

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

=attr filetype

The type of file that this C<Lane> should find if requested (see
L<find_files|Bio::Path::Find::Lane::find_files>).

B<Note> that the default restriction on this attribute allows all of the
file types permitted by the L<FileType|Bio::Path::Find::Types> constraint.
Sub-classes should add more meaningful restrictions like:

  # in Bio::Path::Find::Lane::Class::Data
  has '+filetype' => (
    isa => DataType,
  );

which will make the C<filetype> attribute of a
L<Bio::Path::Find::Lane::Class::Data> object accept only values that pass the
C<DataType> constraint.
=cut

has 'filetype' => (
  is  => 'rw',
  isa => FileType,
);

#---------------------------------------

=attr status

The L<Bio::Path::Find::Lane::Status> object for this lane.

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

  return Bio::Path::Find::Lane::Status->new( lane => $self );
}

#---------------------------------------

=attr store_filenames

Boolean flag controlling whether we store found files as filenames (simple
strings), or as L<Path::Class::File> objects.

In most cases the default behaviour of storing objects is preferable, but in
some situations, such as when the list of files is going to be handed to a
third-party module that doesn't expect L<Path::Class::File> objects, it makes
sense to store filenames. Set this flag to true at instantiation to make the
object store its found files as strings.

=cut

has 'store_filenames' => (
  is      => 'ro',
  isa     => Bool,
  default => 0,
);

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# a flag to show that this lane has run its file-finding process

has '_finding_run' => (
  is      => 'rw',
  isa     => Bool,
  default => 0,
  clearer => '_clear_finding_run',
);

#---------------------------------------

# this is a flag to handle an annoying special case
#
# The usual file-finding process is run via "find_files". If we're looking
# for a specific file type and there's a method to "_get_<filetype>" on the
# Lane class, we use that. If that mechanism doesn't return any files, we
# fall back on the "_get_files_by_extension" method.
#
# With the Lane::Class::RNASeq class, we don't want to fall back on the usual
# "_get_files_by_extension" method, because it bypasses the custom
# file-finding mechanism that takes notice of the "mapper" and "reference"
# command-line options
#
# So, this attribute is a one-use flag to tell the "find_files" method not
# to fall back on "_get_files_by_extension" mechanism.

has '_skip_extension_fallback' => (
  is      => 'ro',
  isa     => Bool,
  builder => '_build_skip_extension_fallback',
);

# set the default in a builder, so that it can be overridden by child classes.
# Default is to fall back on the "_get_files_by_extension" method if possible
sub _build_skip_extension_fallback { 0 }

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

Returns true if this file has B<no> files associated with it, false otherwise.
To be explicit, this is the inverse of L<has_files>.

=head2 file_count

Returns the number of files associated with this lane.

=head2 clear_files

Clears the list of found files. No return value.

=cut

#-------------------------------------------------------------------------------

# these are concrete methods from this class

=head2 find_files($filetype, ?$subdirs)

Look for files associated with this lane with a given filetype. In scalar
context, the method returns the number of files found. In list context, returns
a list of the found files.

Given a specific filetype, this method checks to see if its class has a method
named C<_get_${filetype}> and runs it if the method exists. If there is no such
method, we fall back on a mechanism for finding files based on their extension.

We first look up an extension pattern in the mapping provided by
C<filename_extension>, then call
L<_get_files_by_extension|Bio::Path::Find::Lane::_get_files_by_extension> to
try to find files matching the pattern.

This base class has an empty C<filename_extension> mapping and no C<_get_*>
methods, beyond C<_get_files_by_extensions>. The intention is that the mapping
and C<_get_*> methods will be provided by sub-classes that are specialised to
finding files in a specific context. For example, the C<data> command needs to
find C<fastq> files, so it uses a specialised C<Lane> class,
L<Bio::Path::Find::Lane::Class::Data>, which implements a
C<_get_fastq|Bio::Path::Find::Lane::Class::Data::_get_fastq> method.

If C<$subdirs> is given, it should be a reference to an array containing a list
of sub-directories. Only files within one of the specified sub-directories will
be returned.

B<Note> that calling this method will set the L<filetype> attribute on the
object to C<$filetype>.

=cut

sub find_files {
  state $check = compile( Object, FileType, Optional[Maybe[ArrayRef[PathClassDir]]] );
  my ( $self, $filetype, $subdirs ) = $check->(@_);

  # this is a pretty involved method signature. The $subdirs param is optional,
  # but if it's supplied it should be a ref to an array of Path::Class::Dir
  # objects. However, because it's sometimes hard to avoid passing it in as
  # undef without a lot of hacking in the caller, we also accept undef as a
  # valid value (via the "Maybe"). A value of undef is just ignored in the
  # method.

  $self->filetype($filetype);

  $self->clear_files;
  $self->_clear_finding_run;

  # see if this Lane has a "_get_<filetype>" method, which will come from a
  # Role applied when the Lane is instantiated
  my $method_name = "_get_$filetype";
  $self->$method_name if $self->can($method_name);

  # can't find files of a specific type; should we fall back on the mapping
  # between filetype and filename extension ?
  my $extension = $self->filetype_extensions->{$filetype};

  # should we try to find files using their filename extension ? Yes, if...
  if ( $self->has_no_files and                  # we didn't find any files so far...
       defined $extension  and                  # there's an extension we can use...
       not $self->_skip_extension_fallback ) {  # we've not be told to skip this step
    my $found_files = $self->_get_files_by_extension($extension);
    $self->_set_files($found_files);

    $self->log->debug( 'found ' . $self->file_count . ' files using extension mapping' )
      if $self->has_files;
  }

  # if we have a list of sub-directories, return only files that are in one
  # of the specified directories
  if ( $subdirs and $self->has_files ) {
    my $pb = $self->_create_pb('filtering', $self->file_count * scalar(@$subdirs) );
    my @filtered_files;
    foreach my $file ( $self->all_files ) {
      foreach my $subdir ( @$subdirs ) {
        my $subdir_path = dir( $self->symlink_path, $subdir );
        if ( $subdir_path->contains($file) ) {
          push @filtered_files, $self->store_filenames ? $file : file($file);
        }
        $pb++
      }
    }

    $self->_set_files( \@filtered_files );
  }

  # set the flag showing that we've run file finding on this Lane
  $self->_finding_run(1);

  return wantarray ? $self->all_files : $self->file_count;
}

#-------------------------------------------------------------------------------

=head2 print_paths

Prints the paths for this lane.

If the L<filetype> attribute is set, either directly or by the L<find_files>
method when it runs, this method prints the path to that type of file only. If
file type has not been specified, this method prints the path to the directory
containing all files for this lane.

Returns the number of files found if a file type was specified, or 1 if we're
printing the path to the lane's directory.

=cut

sub print_paths {
  my $self = shift;

  my $rv = 0;
  if ( $self->filetype ) {
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

=head2 make_symlinks( dest => ?$dest, rename => $?rename, filetype => ?$filetype )

Generate symlinks for files from this lane.

If C<$dest> is supplied it must be a L<Path::Class::Dir> giving the destination
directory for the links. An exception is thrown if the destination directory
doesn't exist.

If C<$dest> is not supplied, we create symlinks in the current working
directory.

An optional filetype may also be given. This must be one of "C<fastq>",
"C<bam>", "C<pacbio>" or "C<corrected>" (see L<Bio::Path::Find::Types>, type
C<FileType>). If C<$filetype> is supplied, the lane will look for files of the
specified type, even if it has already searched for files, allowing the caller
to override the filetype that was specified when instantiating the
L<Bio::Path::Find::Lane> object.

If the destination path already exists, either as a link or as a regular file,
we issue a warning and skip the file. There is no option to overwrite existing
files/links; move or delete them before trying to create new links.

If C<$rename> is true, filenames will be created with hashes (#) converted into
underscores (_).

This method throws an exception if it cannot create symlinks, possibly because
perl itself can't create links on the current platform.

Returns a reference to an array containing a list of linked entities (either
file or directory paths, depending on what was found).

=cut

sub make_symlinks {
  state $check = compile(
    Object,
    slurpy Dict[
      dest     => Optional[PathClassDir],
      rename   => Optional[Bool],
      filetype => Optional[FileType],
    ],
  );
  my ( $self, $params ) = $check->(@_);

  if ( not defined $params->{dest} ) {
    $self->log->debug('using current directory as destination');
    $params->{dest} = dir getcwd;
  }

  unless ( -d $params->{dest} ) {
    Bio::Path::Find::Exception->throw(
      msg => 'ERROR: destination for symlinks does not exist or is not a directory ('
             . $params->{dest} . ')' );
  }

  if ( $params->{filetype} ) {
    $self->log->debug( 'find files of type "' . $params->{filetype} . '"' );
    $self->find_files( $params->{filetype} );
  }

  my $links;
  if ( $self->_finding_run ) {
    if ( $self->has_no_files ) {
      carp 'WARNING: no files found for linking';
      return 0;
    }
    $links = $self->_make_file_symlinks( $params->{dest}, $params->{rename} );
  }
  else {
    $links = $self->_make_dir_symlink( $params->{dest}, $params->{rename} );
  }

  return $links;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# make a link to the found files for this lane
#
# returns a reference to an array containing the list of files that we linked,
# or an empty array if we couldn't create any links

sub _make_file_symlinks {
  my ( $self, $dest, $rename ) = @_;

  my @links = ();
  FILE: foreach my $src_file ( $self->all_files ) {

    my $filename = file($src_file)->basename;

    # do we need to rename the link (convert hashes to underscores) ?
    $filename =~ s/\#/_/g if $rename;

    my $dst_file = file( $dest, $filename );

    # provide a hook for Lane Roles to edit filenames, if necessary
    #
    # if the Lane has a "_edit_link_filenames" method, which should come from a
    # Lane sub-class, call the method to edit the "from" and "to" filenames for
    # the link
    ( $src_file, $dst_file ) = $self->_edit_filenames( $src_file, $dst_file )
      if $self->can('_edit_filenames');

    # sanity check: don't overwrite the destination file
    if ( -f $dst_file ) {
      carp qq(WARNING: destination file ($dst_file) already exists; skipping.);
      next FILE;
    }

    if ( -l $dst_file ) {
      carp qq(WARNING: destination file ($dst_file) is already a symlink; skipping.);
      next FILE;
    }

    # the "symlink" call will die if it simply can't make symlinks on this
    # platform, but it returns false if it can't create a link for another
    # reason, such as when the destination file already exists. We need to
    # check for those two outcomes (exception versus return value) separately.

    my $success = 0;
    try {
      $success = symlink( $src_file, $dst_file );
    }
    catch {
      # this should only happen if perl can't create symlinks on the current
      # platform
      Bio::Path::Find::Exception->throw( msg => "ERROR: cannot create symlinks: $_" );
    };

    if ( $success ) {
      push @links, $src_file;
    }
    else {
      carp qq(WARNING: failed to create symlink for "$src_file");
    }
  }

  $self->log->debug('created ' . scalar @links . ' links');

  return \@links;
}

#-------------------------------------------------------------------------------

# make a link to the directory containing the files for this lane. Actually, we
# make a link to the link to that directory, but... semantics
#
# returns a reference to an array containing the name of the directory that we
# linked, or an empty array if we couldn't create the link

sub _make_dir_symlink {
  my ( $self, $dest, $rename ) = @_;

  # symlink_path gives the path to the directory containing the data files for
  # the lane. Here we chop off the final component of that path and use that
  # as the basis for the symlink that we'll create
  my $dir_name = $self->symlink_path->dir_list(-1);

  # do we need to rename the link (convert hashes to underscores) ?
  $dir_name =~ s/\#/_/g if $rename;

  my $src_dir = $self->symlink_path;
  my $dst_dir = file( $dest, $dir_name );

  # TODO should we add a call to "_edit_filenames" here too ?

  if ( -e $dst_dir ) {
    carp qq(WARNING: destination dir ($dst_dir) already exists; skipping.);
    return 0;
  }

  if ( -l $dst_dir ) {
    carp qq(WARNING: destination dir ($dst_dir) is already a symlink; skipping.);
    return 0;
  }

  my $success = 0;
  try {
    $success = symlink( $src_dir, $dst_dir );
  }
  catch {
    # this should only happen if perl can't create symlinks on the current
    # platform
    Bio::Path::Find::Exception->throw(
      msg => "ERROR: cannot create symlinks: $_" );
  };

  carp qq(WARNING: failed to create symlink for "$dest") unless $success;

  # if we succeeded in creating a symlink to the destination directory, return
  # a ref to an array with that single path. Otherwise, return an empty
  # directory and let the caller handle it
  return $success ? [ $dst_dir ] : [];
}

#-------------------------------------------------------------------------------

# find files by looking for files with the specified extension

sub _get_files_by_extension {
  my ( $self, $extension ) = @_;

  $self->log->trace(qq(searching for files with extension "$extension"));

  my @files =
    File::Find::Rule->file->extras( { follow => 1 } )
    ->maxdepth( $self->search_depth )->name($extension)
    ->in( $self->symlink_path );

  $self->log->trace( 'found ' . scalar @files . ' files using extension' );

  # should we store filenames as Path::Class::File objects, or as plain
  # strings ?
  @files = map { file $_ } @files if not $self->store_filenames;

  return \@files;
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

