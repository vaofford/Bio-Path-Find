
package Bio::Path::Find::App::PathFind;

# ABSTRACT: the guts of a pathfind app

use v5.10; # for "say"

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw( carp croak );
use Path::Class;
use Term::ProgressBar;
use Try::Tiny;
use IO::Compress::Gzip;
use File::Temp;
use Text::CSV_XS;
use Archive::Tar;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

use Types::Standard qw(
  ArrayRef
  Str
  +Bool
);

use Bio::Path::Find::Types qw(
  FileType
  QCState
  +PathClassDir  DirFromStr
  +PathClassFile FileFromStr
);

# the boilerplate functionality for this class comes from the AppRole
with 'Bio::Path::Find::App::Role::AppRole',
     'MooseX::Log::Log4perl';

=head1 DESCRIPTION

  Find information about sequencing files.

  Required:
    -i,  --id <ID>                  ID to find, or name of file containing IDs to find
    -t,  --type <type>              type of ID(s); lane|sample|library|study|species|file

    -ft, --file_id_type <filetype>  type of IDs in file input file; lane|sample
                                    Required if type is "file"
  Filters:
    -ft, --filetype <filetype>      type of file to return; fastq|bam|pacbio|corrected
    -q,  --qc <status>              filter on QC status; passed|failed|pending

  Output:
    -s,  --stats <output file>      create a file containing statistics for found data
    -l,  --symlink [<dest dir>]     create symbolic links to data files in the destination dir
    -a,  --archive [<archive name>] create an archive of found files
    -z   --zip                      create zip archives (default is to create tar archives)
    -r,  --rename                   convert hash (#) to underscore (_) in output filenames
    -n,  --no-progress-bars         don't show progress bars when archiving
    -h,  -?                         print this message

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

has 'filetype' => (
  documentation => 'file type to find; fastq | bam | pacbio | corrected',
  is            => 'rw',
  isa           => FileType,
  cmd_aliases   => 'f',
  traits        => ['Getopt'],
);

has 'qc' => (
  documentation => 'QC state; passed | failed | pending',
  is            => 'rw',
  isa           => QCState,
  cmd_aliases   => 'q',
  traits        => ['Getopt'],
);

# TODO implement these

has 'symlink' => (
  documentation => 'create symlinks for data files in the specified directory',
  is            => 'rw',
  isa           => PathClassDir->plus_coercions(DirFromStr), # (coerce from strings to Path::Class::Dir objects)
  cmd_aliases   => 'l',
  traits        => ['Getopt'],
  trigger       => sub {
    my ( $self, $new_dir, $old_dir ) = @_;
    # throw an exception unless the specified directory is sensible
    croak 'ERROR: no such directory, ' . $new_dir unless -d $new_dir;
  },
);
has 'stats' => (
  documentation => 'filename for statistics output',
  is            => 'rw',
  isa           => Str,
  cmd_aliases   => 's',
  traits        => ['Getopt'],
);

has 'rename' => (
  documentation => 'replace hash (#) with underscore (_) in filenames',
  is            => 'rw',
  isa           => Bool,
  cmd_aliases   => 'r',
  traits        => ['Getopt'],
);

has 'no_progress_bars' => (
  documentation => "don't show progress bars when archiving files",
  is            => 'ro',
  isa           => Bool,
  cmd_aliases   => 'n',
  traits        => ['Getopt'],
);

has 'archive' => (
  documentation => 'filename for archive',
  is            => 'rw',
  isa           => Bool|Str,
  cmd_aliases   => 'a',
  traits        => ['Getopt'],
);

has 'zip' => (
  documentation => 'archive data in ZIP format',
  is            => 'ro',
  isa           => Bool,
  cmd_aliases   => 'z',
  traits        => ['Getopt'],
);

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
  # the dummy
  my %finder_params = (
    ids  => $self->_ids,
    type => $self->_type,
  );
  $finder_params{qc}       = $self->qc       if defined $self->qc;
  $finder_params{filetype} = $self->filetype if defined $self->filetype;

  # find lanes
  my $lanes = $self->_finder->find_lanes(%finder_params);

  #---------------------------------------

  $self->log->debug( 'found ' . scalar @$lanes . ' lanes' );

  if ( $self->symlink ) {
    foreach my $lane ( @$lanes ) {
      $lane->make_symlinks( dest => $self->symlink, rename => $self->rename );
    }
  }
  elsif ( $self->archive ) {
    $self->_make_archive($lanes);
  }
  else {
    $_->print_paths for ( @$lanes );
  }

}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# make a gzip-compressed tar archive of the data files for the found lanes

sub _make_archive {
  my ( $self, $lanes ) = @_;

  if ( scalar @$lanes < 1 ) {
    say 'Found no data to archive.';
    exit;
  }

  my $archive_filename = $self->_build_filename;

  say "Archiving lane data to '$archive_filename'";

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

    # write it to file
    unless ( $zip->writeToFileNamed($archive_filename) == AZ_OK ) {
      croak "ERROR: couldn't write zip file ($archive_filename)";
    }
  }
  else {
    # build the tar archive in memory
    my $tar = $self->_build_tar_archive($filenames);

    # we could write the archive in a single call, like this:
    #   $tar->write( $tar_filename, COMPRESS_GZIP );
    # but it's nicer to have a progress bar. Since gzipping and writing can be
    # performed as separate operations, we'll do progress bars for both of them

    # gzip compress the archive
    my $compressed_tar = $self->_compress_data( $tar->write );

    # and write it out, gzip compressed
    $self->_write_data( $compressed_tar, $archive_filename );
  }

  #---------------------------------------

  say "added $_" for @$filenames;
}

#-------------------------------------------------------------------------------

sub _build_filename {
  my $self = shift;

  my $filename;

  # decide on the name of the tar archive
  if ( not is_Bool($self->archive) ) {
    $self->log->debug('archive attribute is a PathClassFile; using it as a filename');
    $filename = $self->archive;
  }
  else {
    $self->log->debug('archive attribute is a boolean; building a filename');
    # we'll ALWAYS make a sensible name for the archive itself
    ( my $renamed_id = $self->id ) =~ s/\#/_/g;
    $filename = $self->zip
              ? "pathfind_$renamed_id.zip"
              : "pathfind_$renamed_id.tar.gz";
  }

  return $filename;
}

#-------------------------------------------------------------------------------

# retrieves the list of filenames associated with the supplied lanes

sub _collect_filenames {
  my ( $self, $lanes ) = @_;

  my $max = scalar @$lanes;
  my $progress_bar = Term::ProgressBar->new( {
    name   => 'finding files',
    count  => $max,
    remove => 1,
    silent => $self->no_progress_bars,
  } );
  $progress_bar->minor(0); # ditch the "completion time estimator" character

  # collect the lane stats as we go along. Store the headers for the stats
  # report as the first row
  my @stats = ( $lanes->[0]->stats_headers );

  my @filenames;
  my $next_update = 0;
  for ( my $i = 0; $i < $max; $i++ ) {
    my $lane = $lanes->[$i];

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

    $next_update = $progress_bar->update($i);
  }

  # we need to make sure that $next_update is defined, because if we run with
  # "silent => 0", i.e. if we don't want to show any progress bars, calls to
  # $progress_bar->update don't return a value, so we end up with pages of
  # uninitialized value warnings
  $progress_bar->update($next_update)
    if ( defined $next_update and $max >= $next_update );

  return ( \@filenames, \@stats );
}

#-------------------------------------------------------------------------------

# creates a tar archive containing the specified files

sub _build_tar_archive {
  my ( $self, $filenames ) = @_;

  my $tar = Archive::Tar->new;

  # doesn't look like we can add files individually, as we'd need to if we
  # wanted to show a progress bar...
  $tar->add_files(@$filenames);

  # the files are added with their full paths. We want them to be relative,
  # so we'll go through the archive and rename them all. If the "-rename"
  # option is specified, we'll also rename the individual files to convert
  # hashes to underscores
  foreach my $orig_filename ( @$filenames ) {

    my $tar_filename = $self->_rename_file($orig_filename);

    # filenames in the archive itself are relative to the root directory, i.e.
    # they lack a leading slash. Trim off that slash before trying to rename
    # files in the archive, otherwise they're simply not found
    $orig_filename =~ s|^/||;

    $tar->rename( $orig_filename, $tar_filename )
      or carp "WARNING: couldn't rename '$orig_filename' in archive";
  }

  return $tar;
}

#-------------------------------------------------------------------------------

# creates a ZIP archive containing the specified files

sub _build_zip_archive {
  my ( $self, $filenames ) = @_;

  my $zip = Archive::Zip->new;

  my $max = scalar @$filenames;
  my $next_update = 0;
  my $progress_bar = Term::ProgressBar->new( {
    name   => 'adding files',
    count  => $max,
    remove => 1,
    silent => $self->no_progress_bars,
  } );
  $progress_bar->minor(0);

  for ( my $i = 0; $i < scalar @$filenames; $i++ ) {
    my $orig_filename = $filenames->[$i];
    my $zip_filename  = $self->_rename_file($orig_filename);

    # to-string the filenames, to avoid the Path::Class::File object going into
    # the zip archive
    $zip->addFile("$orig_filename", "$zip_filename");

    $next_update = $progress_bar->update($i);
  }

  $progress_bar->update($next_update)
    if ( defined $next_update and $max >= $next_update );

  return $zip;
}

#-------------------------------------------------------------------------------

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
  my $progress_bar = Term::ProgressBar->new( {
    name   => 'gzipping',
    count  => $max,
    remove => 1,
    silent => $self->no_progress_bars,
  } );
  $progress_bar->minor(0); # ditch the "completion time estimator" character

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
    $next_update = $progress_bar->update($offset)
      if ( defined $next_update and $offset >= $next_update );
  }

  $z->close;

  # tidy up; push the progress bar to 100% so that it will actually be removed
  $progress_bar->update($max)
    if ( defined $next_update and $max >= $next_update );

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

  my $progress_bar = Term::ProgressBar->new( {
    name   => 'writing',
    count  => $max,
    remove => 1,
    silent => $self->no_progress_bars,
  } );
  $progress_bar->minor(0);

  open ( FILE, '>', $filename )
    or croak "ERROR: couldn't write output file ($filename): $!";

  binmode FILE;

  my $written;
  my $offset      = 0;
  my $next_update = 0;
  my $remaining   = $max;
  while ( $remaining > 0 ) {
    $written = syswrite FILE, $data, $chunk_size, $offset;
    $offset    += $written;
    $remaining -= $written;
    $next_update = $progress_bar->update($offset)
      if ( defined $next_update and $offset >= $next_update );
  }

  close FILE;

  $progress_bar->update($max)
    if ( defined $next_update and $max >= $next_update );
}

#-------------------------------------------------------------------------------

# writes the supplied lane statistics in CSV format to the specified file

sub _write_stats_csv {
  my ( $self, $stats, $filename ) = @_;

  croak 'ERROR: must supply a filename for the stats report'
    unless defined $filename;

  my $fh = FileHandle->new;

  # see if the supplied filename exists and complain if it does
  croak 'ERROR: stats CSV file already exists; not overwriting existing file'
    if -e $filename;

  $fh->open( $filename, '>' );

  my $csv = Text::CSV_XS->new;
  $csv->eol("\n");
  $csv->print($fh, $_) for @$stats;

  $fh->close;
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

