
package Bio::Path::Find::Role::Archivist;

# ABSTRACT: role providing methods for archiving data

use v5.10; # for "say"

use MooseX::App::Role;

=head1 CONTACT

path-help@sanger.ac.uk

=cut

use Cwd;
use Path::Class;
use File::Temp;
use Try::Tiny;
use IO::Compress::Gzip;
use Archive::Tar;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Carp qw( carp );

use Bio::Path::Find::Exception;

use Types::Standard qw(
  ArrayRef
  +Str
  +Bool
);

use Bio::Path::Find::Types qw( :types );

with 'Bio::Path::Find::Role::HasProgressBar';

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# set up "archive" like we set up "symlink". See also B::P::F::Role::Linker.

option 'archive' => (
  documentation => 'create a tar archive of data files',
  is            => 'rw',
  # no "isa" because we want to accept both Bool and Str
  cmd_aliases   => 'a',
  trigger       => \&_check_for_archive_value,
);

sub _check_for_archive_value {
  my ( $self, $new, $old ) = @_;

  if ( not defined $new ) {
    $self->_tar_flag(1);
  }
  elsif ( not is_Bool($new) ) {
    $self->_tar_flag(1);
    $self->_tar( file $new );
  }
  else {
    $self->_tar_flag(0);
  }
}

has '_tar_flag' => ( is => 'rw', isa => Bool );

has '_tar'      => (
  is => 'rw',
  isa => PathClassFile,
  lazy => 1,
  builder => '_build_tar_filename',
);

# specify the default tar file name here, so that it can be overridden by
# a method in a Lane that applies this Role
sub _build_tar_filename {
  my $self = shift;
  return file( 'pf_' . $self->_renamed_id . ( $self->no_tar_compression ? '.tar' : '.tar.gz' ) );
}

#---------------------------------------

# set up "zip" like we set up "symlink"

option 'zip' => (
  documentation => 'create a zip archive of data files',
  is            => 'rw',
  # no "isa" because we want to accept both Bool and Str
  cmd_aliases   => 'z',
  trigger       => \&_check_for_zip_value,
);

sub _check_for_zip_value {
  my ( $self, $new, $old ) = @_;

  if ( not defined $new ) {
    $self->_zip_flag(1);
  }
  elsif ( not is_Bool($new) ) {
    $self->_zip_flag(1);
    $self->_zip( file $new );
  }
  else {
    $self->_zip_flag(0);
  }
}

has '_zip_flag' => ( is => 'rw', isa => Bool );

has '_zip' => (
  is      => 'rw',
  isa     => PathClassFile,
  lazy    => 1,
  builder => '_build_zip_filename',
);

# specify the default zip file name here, so that it can be overridden by
# a method in a Lane that applies this Role
sub _build_zip_filename {
  my $self = shift;
  return file( 'pf_' . $self->_renamed_id . '.zip' );
}

#---------------------------------------

option 'no_tar_compression' => (
  documentation => "don't compress tar archives",
  is            => 'rw',
  isa           => Bool,
  cmd_flag      => 'no-tar-compression',
  cmd_aliases   => 'u',
);

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# make a tar archive of the data files for the found lanes

sub _make_tar {
  my ( $self, $lanes ) = @_;

  my $archive_filename = $self->_tar;

  say STDERR "Archiving lane data to '$archive_filename'";

  # collect the list of files to archive
  my ( $filenames, $stats ) = $self->_collect_filenames($lanes);

  # write a CSV file with the stats and add it to the list of files that
  # will go into the archive
  my $temp_dir = File::Temp->newdir;
  my $stats_file = file( $temp_dir, 'stats.csv' );
  $self->_write_csv($stats, $stats_file);

  push @$filenames, $stats_file;

  # build the tar archive in memory
  my $tar = $self->_create_tar_archive($filenames);

  # we could write the archive in a single call, like this:
  #   $tar->write( $tar_filename, COMPRESS_GZIP );
  # but it's nicer to have a progress bar. Since gzipping and writing can be
  # performed as separate operations, we'll do progress bars for both of them

  # get the contents of the tar file. This is a little slow but we can't
  # break it down and use a progress bar, so at least tell the user what's
  # going on
  print STDERR 'Building tar file... ';
  my $tar_contents = $tar->write;
  print STDERR "done\n";

  # gzip compress the archive ?
  my $output = $self->no_tar_compression
             ? $tar_contents
             : $self->_compress_data($tar_contents);

  # and write it out
  $self->_write_data( $output, $archive_filename );

  #---------------------------------------

  # list the contents of the archive. Strip the path from stats.csv, since it's
  # a file that we generate in a temp directory. That temp dir is deleted as
  # soon as the file is archived, so it's meaningless to the user
  say m|/stats.csv$| ? 'stats.csv' : $_ for @$filenames;
}

#-------------------------------------------------------------------------------

# make a zip archive of the data files for the found lanes

sub _make_zip {
  my ( $self, $lanes ) = @_;

  my $archive_filename = $self->_zip;

  say STDERR "Archiving lane data to '$archive_filename'";

  # collect the list of files to archive
  my ( $filenames, $stats ) = $self->_collect_filenames($lanes);

  # write a CSV file with the stats and add it to the list of files that
  # will go into the archive
  my $temp_dir = File::Temp->newdir;
  my $stats_file = file( $temp_dir, 'stats.csv' );
  $self->_write_csv($stats, $stats_file);

  push @$filenames, $stats_file;

  #---------------------------------------

  # build the zip archive in memory
  my $zip = $self->_create_zip_archive($filenames);

  print STDERR 'Writing zip file... ';

  # write it to file
  if ( -e $archive_filename and not $self->force ) {
    Bio::Path::Find::Exception->throw(
      msg => qq(ERROR: output file "$archive_filename" already exists; not overwriting. Use "-F" to force overwriting)
    );
  }

  try {
    unless ( $zip->writeToFileNamed($archive_filename->stringify) == AZ_OK ) {
      print STDERR "failed\n";
      Bio::Path::Find::Exception->throw( msg => "ERROR: couldn't write zip file ($archive_filename)" );
    }
  } catch {
    Bio::Path::Find::Exception->throw( msg => "ERROR: error while writing zip file ($archive_filename): $_" );
  };

  print STDERR "done\n";

  #---------------------------------------

  # list the contents of the archive. Strip the path from stats.csv, since it's
  # a file that we generate in a temp directory. That temp dir is deleted as
  # soon as the file is archived, so it's meaningless to the user
  say m|/stats.csv$| ? 'stats.csv' : $_ for @$filenames;
}

#-------------------------------------------------------------------------------

# retrieves the list of filenames associated with the supplied lanes

sub _collect_filenames {
  my ( $self, $lanes ) = @_;

  my $pb = $self->_create_pb('collecting files', scalar @$lanes);

  # collect the lane stats as we go along. Store the headers for the stats
  # report as the first row
  my @stats = ( $lanes->[0]->stats_headers );

  my @filenames;
  foreach my $lane ( @$lanes ) {
    push @filenames, $lane->all_files;
    push @stats,     @{ $lane->stats };
    $pb++;
  }

  return ( \@filenames, \@stats );
}

#-------------------------------------------------------------------------------

# creates a tar archive containing the specified files

sub _create_tar_archive {
  my ( $self, $filenames ) = @_;

  my $tar = Archive::Tar->new;

  my $pb = $self->_create_pb('adding files', scalar @$filenames);

  foreach my $filename ( @$filenames ) {
    $tar->add_files($filename);
    $pb++;
  }

  # the files are added with their full paths. We want them to be relative,
  # so we'll go through the archive and rename them all. If the "-rename"
  # option is specified, we'll also rename the individual files to convert
  # hashes to underscores
  foreach my $orig_filename ( @$filenames ) {

    my $tar_filename = $self->_rename_file($orig_filename);

    # filenames in the archive itself are relative to the root directory, i.e.
    # they lack a leading slash. Trim off that slash before trying to rename
    # files in the archive, otherwise they're simply not found. Take a copy
    # of the original filename before we trim it, to avoid stomping on the
    # original
    ( my $trimmed_filename = $orig_filename ) =~ s|^/||;

    $tar->rename( $trimmed_filename, $tar_filename )
      or carp "WARNING: couldn't rename '$trimmed_filename' in archive";
  }

  return $tar;
}

#-------------------------------------------------------------------------------

# creates a ZIP archive containing the specified files

sub _create_zip_archive {
  my ( $self, $filenames ) = @_;

  my $zip = Archive::Zip->new;

  my $pb = $self->_create_pb('adding files', scalar @$filenames);

  foreach my $orig_filename ( @$filenames ) {
    my $zip_filename  = $self->_rename_file($orig_filename);

    # this might not be strictly necessary, but there were some strange things
    # going on while testing this operation: stringify the filenames, to avoid
    # the Path::Class::File object going into the zip archive
    $zip->addFile($orig_filename->stringify, $zip_filename->stringify);

    $pb++;
  }

  return $zip;
}

#-------------------------------------------------------------------------------

# gzips the supplied data and returns the compressed data

sub _compress_data {
  my ( $self, $data ) = @_;

  $DB::single = 1;

  my $max        = length $data;
  my $num_chunks = 100;
  my $chunk_size = int( $max / $num_chunks );

  # set up the progress bar
  my $pb = $self->_create_pb('gzipping', $num_chunks + 1);

  my $compressed_data;
  my $offset      = 0;
  my $remaining   = $max;
  my $z           = IO::Compress::Gzip->new( \$compressed_data );
  while ( $remaining > 0 ) {
    # write the data in chunks
    my $chunk = ( $chunk_size > $remaining )
              ? substr $data, $offset
              : substr $data, $offset, $chunk_size;

    $z->print($chunk);

    $offset    += $chunk_size;
    $remaining -= $chunk_size;
    $pb++;
  }

  $z->close;

  return $compressed_data;
}

#-------------------------------------------------------------------------------

# writes the supplied data to the specified file. This method doesn't care what
# form the data take, it just dumps the raw data to file, showing a progress
# bar if required.

sub _write_data {
  my ( $self, $data, $filename ) = @_;

  if ( -e $filename and not $self->force ) {
    Bio::Path::Find::Exception->throw(
      msg => qq(ERROR: output file "$filename" already exists; not overwriting. Use "-F" to force overwriting)
    );
  }

  my $max        = length $data;
  my $num_chunks = 100;
  my $chunk_size = int( $max / $num_chunks );

  my $pb = $self->_create_pb('writing', $num_chunks + 1);

  open ( FILE, '>', $filename )
    or Bio::Path::Find::Exception->throw( msg => "ERROR: couldn't write output file ($filename): $!" );

  binmode FILE;

  my $written;
  my $offset      = 0;
  my $remaining   = $max;
  while ( $remaining > 0 ) {
    $written = syswrite FILE, $data, $chunk_size, $offset;
    $offset    += $written;
    $remaining -= $written;
    $pb++;
  }

  close FILE;
}

#-------------------------------------------------------------------------------

1;
