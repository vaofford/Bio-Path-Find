
package Bio::Path::Find::App::PathFind;

# ABSTRACT: find files and directories for sequencing lanes

use v5.10; # for "say"

use MooseX::App::Simple qw( Depends );
# use namespace::autoclean; # leave out; messes with MooseX::App
use MooseX::StrictConstructor;

use Carp qw( carp );
use Path::Class;
use Try::Tiny;
use IO::Compress::Gzip;
use File::Temp;
use Text::CSV_XS;
use Archive::Tar;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Cwd;

use Bio::Path::Find::Exception;
use Bio::Path::Find::ProgressBar;

use Types::Standard qw(
  ArrayRef
  +Str
  +Bool
);

use Bio::Path::Find::Types qw(
  FileType
  QCState
  +PathClassDir  DirFromStr
  +PathClassFile FileFromStr
);

with 'MooseX::Log::Log4perl',
     'Bio::Path::Find::App::Role::AppRole';


=head1 USAGE

pathfind --type <ID type> --id <id> [options]

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

option 'filetype' => (
  documentation => 'type of files to find',
  is            => 'ro',
  isa           => FileType,
  cmd_aliases   => 'f',
);

option 'qc' => (
  documentation => 'filter results by lane QC state',
  is            => 'ro',
  isa           => QCState,
  cmd_aliases   => 'q',
);

option 'rename' => (
  documentation => 'replace hash (#) with underscore (_) in filenames',
  is            => 'rw',
  isa           => Bool,
  cmd_aliases   => 'r',
);

option 'zip' => (
  documentation => 'archive data in ZIP format',
  is            => 'ro',
  isa           => Bool,
  cmd_aliases   => 'z',
  depends       => [ 'archive' ],
);
#---------------------------------------

# this option can be used as a simple switch ("-l") or with an argument
# ("-l mydir"). It's a bit fiddly to set that up...

option 'symlink' => (
  documentation => 'create symlinks for data files in the specified directory',
  is            => 'ro',
  cmd_aliases   => 'l',
  trigger       => \&_check_for_symlink_value,
  # no "isa" because we want to accept both Bool and Str and it doesn't seem to
  # be possible to specify that using the combination of MooseX::App and
  # Type::Tiny that we're using here
);

# set up a trigger that checks for the value of the "symlink" command-line
# argument and tries to decide if it's a boolean, in which case we'll generate
# a directory name to hold links, or a string, in which case we'll treat that
# string as a directory name.
sub _check_for_symlink_value {
  my ( $self, $new, $old ) = @_;

  if ( not defined $new ) {
    # make links in a directory whose name we'll set ourselves
    $self->_symlink_flag(1);
  }
  elsif ( not is_Bool($new) ) {
    # make links in the directory specified by the user
    $self->_symlink_flag(1);
    $self->_symlink_dir( dir $new );
  }
  else {
    # don't make links. Shouldn't ever get here
    $self->_symlink_flag(0);
  }
}

# private attributes to store the (optional) value of the "symlink" attribute.
# When using all of this we can check for "_symlink_flag" being true or false,
# and, if it's true, check "_symlink_dir" for a value
has '_symlink_dir'  => ( is => 'rw', isa => PathClassDir );
has '_symlink_flag' => ( is => 'rw', isa => Bool );

#---------------------------------------

# set up "archive" like we set up "symlink". No need to register a new
# subtype again though

option 'archive' => (
  documentation => 'filename for archive',
  is            => 'rw',
  # no "isa" because we want to accept both Bool and Str
  cmd_aliases   => 'a',
  trigger       => \&_check_for_archive_value,
);

sub _check_for_archive_value {
  my ( $self, $new, $old ) = @_;

  if ( not defined $new ) {
    $self->_archive_flag(1);
  }
  elsif ( not is_Bool($new) ) {
    $self->_archive_flag(1);
    $self->_archive_dir( dir $new );
  }
  else {
    $self->_archive_flag(0);
  }
}

has '_archive_dir'  => ( is => 'rw', isa => PathClassDir );
has '_archive_flag' => ( is => 'rw', isa => Bool );

#---------------------------------------

option 'stats' => (
  documentation => 'filename for statistics CSV output',
  is            => 'rw',
  # no "isa" because we want to accept both Bool and Str
  cmd_aliases   => 's',
  trigger       => \&_check_for_stats_value,
);

sub _check_for_stats_value {
  my ( $self, $new, $old ) = @_;

  if ( not defined $new ) {
    $self->_stats_flag(1);
  }
  elsif ( not is_Bool($new) ) {
    $self->_stats_flag(1);
    $self->_stats_file( file $new );
  }
  else {
    $self->_stats_flag(0);
  }
}

has '_stats_file' => ( is => 'rw', isa => PathClassFile );
has '_stats_flag' => ( is => 'rw', isa => Bool );

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 run

Find files according to the input parameters.

=cut

sub run {
  my $self = shift;

  # log the command line to file
  $self->_log_command;

  # set up the finder

  # build the parameters for the finder. Omit undefined options or Moose spits
  # the dummy (by design)
  my %finder_params = (
    ids  => $self->_ids,
    type => $self->_type,
  );
  $finder_params{qc}       = $self->qc       if defined $self->qc;
  $finder_params{filetype} = $self->filetype if defined $self->filetype;

  # find lanes
  my $lanes = $self->_finder->find_lanes(%finder_params);

  $self->log->debug( 'found ' . scalar @$lanes . ' lanes' );

  if ( scalar @$lanes < 1 ) {
    say STDERR 'No data found.';
    exit;
  }

  # do something with the found lanes
  if ( $self->_symlink_flag ) {
    $self->_make_symlinks($lanes);
  }
  elsif ( $self->_archive_flag ) {
    $self->_make_archive($lanes);
  }
  elsif ( $self->_stats_flag ) {
    $self->_make_stats($lanes);
  }
  else {
    $_->print_paths for ( @$lanes );
  }

}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# make symlinks for found lanes

sub _make_symlinks {
  my ( $self, $lanes ) = @_;

  my $dest;

  if ( $self->_symlink_dir ) {
    $self->log->debug('symlink attribute specifies a dir name');
    $dest = $self->_symlink_dir;
  }
  else {
    $self->log->debug('symlink attribute is a boolean; building a dir name');
    $dest = dir( getcwd(), 'pathfind_' . $self->_renamed_id );
  }

  try {
    $dest->mkpath unless -d $dest;
  } catch {
    Bio::Path::Find::Exception->throw(
      msg => "ERROR: couldn't make link directory ($dest)"
    );
  };

  # should be redundant, but...
  Bio::Path::Find::Exception->throw( msg =>  "ERROR: not a directory ($dest)" )
    unless -d $dest;

  say STDERR "Creating links in '$dest'";

  my $progress_bar = Bio::Path::Find::ProgressBar->new(
    name   => 'linking',
    count  => scalar @$lanes,
    silent => $self->no_progress_bars,
  );

  my $i = 0;
  foreach my $lane ( @$lanes ) {
    $lane->make_symlinks( dest => $dest, rename => $self->rename );
    $progress_bar->update($i++);
  }

  $progress_bar->finished;
}

#-------------------------------------------------------------------------------

# make an archive of the data files for the found lanes, either tar or zip,
# depending on the "zip" attribute

sub _make_archive {
  my ( $self, $lanes ) = @_;

  my $archive_filename;

  if ( $self->_archive_dir ) {
    $self->log->debug('_archive_dir attribute is set; using it as a filename');
    $archive_filename = $self->_archive_dir;
  }
  else {
    $self->log->debug('_archive_dir attribute is not set; building a filename');
    # we'll ALWAYS make a sensible name for the archive itself
    $archive_filename = 'pathfind_' . $self->_renamed_id . ( $self->zip ? '.zip' : '.tar.gz' );
  }

  say STDERR "Archiving lane data to '$archive_filename'";

  # collect the list of files to archive
  my ( $filenames, $stats ) = $self->_collect_filenames($lanes);

  # write a CSV file with the stats and add it to the list of files that
  # will go into the archive
  my $temp_dir = File::Temp->newdir;
  my $stats_file = file( $temp_dir, 'stats.csv' );
  $self->_write_stats_csv($stats, $stats_file);

  push @$filenames, $stats_file;

  #---------------------------------------

  # zip or tar ?
  if ( $self->zip ) {
    # build the zip archive in memory
    my $zip = $self->_build_zip_archive($filenames);

    print STDERR 'Writing zip file... ';

    # write it to file
    unless ( $zip->writeToFileNamed($archive_filename) == AZ_OK ) {
      print STDERR "failed\n";
      Bio::Path::Find::Exception->throw( msg => "ERROR: couldn't write zip file ($archive_filename)" );
    }

    print STDERR "done\n";
  }
  else {
    # build the tar archive in memory
    my $tar = $self->_build_tar_archive($filenames);

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

    # gzip compress the archive
    my $compressed_tar = $self->_compress_data($tar_contents);

    # and write it out, gzip compressed
    $self->_write_data( $compressed_tar, $archive_filename );
  }

  #---------------------------------------

  # list the contents of the archive
  say $_ for @$filenames;
}

#-------------------------------------------------------------------------------

# retrieves the list of filenames associated with the supplied lanes

sub _collect_filenames {
  my ( $self, $lanes ) = @_;

  my $progress_bar = Bio::Path::Find::ProgressBar->new(
    name   => 'finding files',
    count  => scalar @$lanes,
    silent => $self->no_progress_bars,
  );

  # collect the lane stats as we go along. Store the headers for the stats
  # report as the first row
  my @stats = ( $lanes->[0]->stats_headers );

  my @filenames;
  my $i = 0;
  foreach my $lane ( @$lanes ) {

    # if the Finder was set up to look for a specific filetype, we don't need
    # to do a find here. If it was not given a filetype, it won't have looked
    # for data files, just the directory for the lane, so we need to find data
    # files here explicitly
    $lane->find_files('fastq') if not $self->filetype;

    foreach my $filename ( $lane->all_files ) {
      push @filenames, $filename;
    }

    # store the stats for this lane
    push @stats, $lane->stats;

    $progress_bar->update($i++);
  }

  $progress_bar->finished;

  return ( \@filenames, \@stats );
}

#-------------------------------------------------------------------------------

# creates a tar archive containing the specified files

sub _build_tar_archive {
  my ( $self, $filenames ) = @_;

  my $tar = Archive::Tar->new;

  my $progress_bar = Bio::Path::Find::ProgressBar->new(
    name   => 'adding files',
    count  => scalar @$filenames,
    silent => $self->no_progress_bars,
  );

  my $i = 0;
  foreach my $filename ( @$filenames ) {
    $tar->add_files($filename);
    $progress_bar->update($i++);
  }
  $progress_bar->finished;

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

sub _build_zip_archive {
  my ( $self, $filenames ) = @_;

  my $zip = Archive::Zip->new;

  my $progress_bar = Bio::Path::Find::ProgressBar->new(
    name   => 'adding files',
    count  => scalar @$filenames,
    silent => $self->no_progress_bars,
  );

  my $i = 0;
  foreach my $orig_filename ( @$filenames ) {
    my $zip_filename  = $self->_rename_file($orig_filename);

    # this might not be strictly necessary, but there were some strange things
    # going on while testing this operation: stringify the filenames, to avoid
    # the Path::Class::File object going into the zip archive
    $zip->addFile($orig_filename->stringify, $zip_filename->stringify);

    $progress_bar->update($i++);
  }

  $progress_bar->finished;

  return $zip;
}

#-------------------------------------------------------------------------------

# generates a new filename by converting hashes to underscores in the supplied
# filename. Also converts the filename to unix format, for use with tar and
# zip

sub _rename_file {
  my ( $self, $old_filename ) = @_;

  my $new_basename = $old_filename->basename;

  # honour the "-rename" option
  $new_basename =~ s/\#/_/g if $self->rename;

  # add on the folder to get the relative path for the file in the
  # archive
  ( my $folder_name = $self->id ) =~ s/\#/_/g;

  my $new_filename = file( $folder_name, $new_basename );

  # filenames in an archive are specified as Unix paths (see
  # https://metacpan.org/pod/Archive::Tar#tar-rename-file-new_name)
  $old_filename = file( $old_filename )->as_foreign('Unix');
  $new_filename = file( $new_filename )->as_foreign('Unix');

  $self->log->debug( "renaming |$old_filename| to |$new_filename|" );

  return $new_filename;
}

#-------------------------------------------------------------------------------

# gzips the supplied data and returns the compressed data

sub _compress_data {
  my ( $self, $data ) = @_;

  my $max        = length $data;
  my $chunk_size = int( $max / 100 );

  # set up the progress bar
  my $progress_bar = Bio::Path::Find::ProgressBar->new(
    name   => 'gzipping',
    count  => $max,
    silent => $self->no_progress_bars,
  );

  my $compressed_data;
  my $offset      = 0;
  my $next_update = 0;
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
    $progress_bar->update($offset);
  }

  $z->close;

  # tidy up; push the progress bar to 100% so that it will actually be removed
  $progress_bar->finished;

  return $compressed_data;
}

#-------------------------------------------------------------------------------

# writes the supplied data to the specified file. This method doesn't care what
# form the data take, it just dumps the raw data to file, showing a progress
# bar if required.

sub _write_data {
  my ( $self, $data, $filename ) = @_;

  my $max        = length $data;
  my $chunk_size = int( $max / 100 );

  my $progress_bar = Bio::Path::Find::ProgressBar->new(
    name   => 'writing',
    count  => $max,
    silent => $self->no_progress_bars,
  );

  open ( FILE, '>', $filename )
    or Bio::Path::Find::Exception->throw( msg =>  "ERROR: couldn't write output file ($filename): $!" );

  binmode FILE;

  my $written;
  my $offset      = 0;
  my $next_update = 0;
  my $remaining   = $max;
  while ( $remaining > 0 ) {
    $written = syswrite FILE, $data, $chunk_size, $offset;
    $offset    += $written;
    $remaining -= $written;
    $progress_bar->update($offset);
  }

  close FILE;

  $progress_bar->finished;
}

#-------------------------------------------------------------------------------

# build a CSV file with the statistics for all lanes and write it to file

sub _make_stats {
  my ( $self, $lanes ) = @_;

  my $filename;

  # get or build the filename for the output file
  if ( $self->_stats_file ) {
    $self->log->debug('stats attribute specifies a filename');
    $filename = $self->_stats_file;
  }
  else {
    $self->log->debug('stats attribute is a boolean; building a filename');
    $filename = dir( getcwd(), $self->_renamed_id . '.pathfind_stats.csv' );
  }

  # collect the stats for the supplied lanes
  my @stats = (
    $lanes->[0]->stats_headers,
  );

  my $pb = Bio::Path::Find::ProgressBar->new(
    name   => 'finding stats',
    count  => scalar @$lanes,
    silent => $self->no_progress_bars,
  );

  for ( my $i = 0; $i < scalar @$lanes; $i++ ) {
    push @stats, $lanes->[$i]->stats;
    $pb->update($i);
  }

  $pb->finished;

  $self->_write_stats_csv(\@stats, $filename);
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

