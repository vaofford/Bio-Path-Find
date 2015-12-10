
package Bio::Path::Find::App::PathFind;

# ABSTRACT: the guts of a pathfind app

use v5.10; # for "say"

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

use Carp qw( carp croak );
use Path::Class;
use Term::ProgressBar;
use Try::Tiny;
use IO::Compress::Gzip;
use File::Temp;
use Text::CSV_XS;
use Archive::Tar;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Cwd;

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

#---------------------------------------

# this is a bit hairy. The symlink (and later, archive) attribute needs to
# accept either a boolean (if the flag is set on the command line but has
# no argument) or a string (if the flag is set and a value is given). This
# configuration doesn't seem to be possible using a combination of
# MooseX::Getopt and Type::Tiny, hence this ugly work-around, using
# Moose::Util::TypeConstraints instead of Type::Tiny.

# first, set up a boolean-or-string type and register it with MooseX::Getopt as
# accepting an optional string argument
subtype 'BoolOrStr',
  as 'Str';

MooseX::Getopt::OptionTypeMap->add_option_type_to_map( 'BoolOrStr' => ':s' );

# next, set up a trigger that checks for the value of the "symlink"
# command-line argument nd tries to decide if it's a boolean or a string,
# explicitly treating "defined but not set" as true
has 'symlink' => (
  documentation => 'create symlinks for data files in the specified directory',
  is            => 'rw',
  isa           => 'BoolOrStr',
  cmd_aliases   => 'l',
  traits        => ['Getopt'],
  trigger       => \&_check_for_symlink_value,
);

sub _check_for_symlink_value {
  my ( $self, $new_dir, $old_dir ) = @_;
  if ( defined $new_dir and
       $new_dir ne ''   and
       not is_Bool($new_dir) ) {
    $self->_symlink_dir( dir $new_dir);
  }
  elsif ( defined $new_dir
    and $new_dir eq '' ) {
    $self->symlink(1);
  }
}

# finally, set up a private attribute to store the (optional) value of the
# "symlink" attribute. When using all of this we can check for "symlink" being
# true or false, and, if it's true, check "_symlink_dir" for a value
has '_symlink_dir' => (
  is  => 'rw',
  isa => PathClassDir->plus_coercions(DirFromStr),
);

# what a mess...

#---------------------------------------

# set up "archive" like we set up "symlink". No need to register a new
# subtype again though

has 'archive' => (
  documentation => 'filename for archive',
  is            => 'rw',
  isa           => 'BoolOrStr',
  cmd_aliases   => 'a',
  traits        => ['Getopt'],
  trigger       => \&_check_for_archive_value,
);

sub _check_for_archive_value {
  my ( $self, $new_dir, $old_dir ) = @_;
  if ( defined $new_dir and
       $new_dir ne ''   and
       not is_Bool($new_dir) ) {
    $self->_archive_dir( dir $new_dir);
  }
  elsif ( defined $new_dir
    and $new_dir eq '' ) {
    $self->archive(1);
  }
}

has '_archive_dir' => (
  is  => 'rw',
  isa => PathClassDir->plus_coercions(DirFromStr),
);

#---------------------------------------

# TODO implement this

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
  documentation => "don't show progress bars",
  is            => 'ro',
  isa           => Bool,
  cmd_aliases   => 'n',
  traits        => ['Getopt'],
  trigger       => \&_set_progress_bar_flag,
);

# set a flag on the config object to show whether or not interested objects
# should show progress bars when doing work
sub _set_progress_bar_flag {
  my ( $self, $flag, $old_flag ) = @_;
  $self->config->{no_progress_bars} = $flag;
}

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
    say 'No data found.';
    exit;
  }

  # do something with the found lanes
  if ( $self->symlink ) {
    $self->_make_symlinks($lanes);
  }
  elsif ( $self->archive ) {
    $self->_make_archive($lanes);
  }
  elsif ( $self->stats ) {
    # $self->_make_stats($lanes);
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
    ( my $renamed_id = $self->id ) =~ s/\#/_/g;
    $dest = dir( getcwd(), "pathfind_$renamed_id" );
  }

  try {
    $dest->mkpath unless -d $dest;
  } catch {
    croak "ERROR: couldn't make link directory ($dest)";
  };

  # should be redundant, but...
  croak "ERROR: not a directory ($dest)" unless -d $dest;

  say "Creating links in '$dest'";

  my $max = scalar @$lanes;
  my $progress_bar = Term::ProgressBar->new( {
    name   => 'linking',
    count  => $max,
    remove => 1,
    ETA    => 'linear',
    silent => $self->no_progress_bars,
  } );
  $progress_bar->minor(0); # ditch the "completion time estimator" character

  my $next_update = 0;
  for ( my $i = 0; $i < scalar @$lanes; $i++ ) {
    my $lane = $lanes->[$i];

    $lane->make_symlinks( dest => $dest, rename => $self->rename );

    $next_update = $progress_bar->update($i);
  }

  # we need to make sure that $next_update is defined, because if we run with
  # "silent => 0", i.e. if we don't want to show any progress bars, calls to
  # $progress_bar->update don't return a value, so we end up with pages of
  # uninitialized value warnings
  $progress_bar->update($max)
    if ( defined $next_update and $max >= $next_update );
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
    ( my $renamed_id = $self->id ) =~ s/\#/_/g;
    $archive_filename = $self->zip
                      ? "pathfind_$renamed_id.zip"
                      : "pathfind_$renamed_id.tar.gz";
  }

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

# retrieves the list of filenames associated with the supplied lanes

sub _collect_filenames {
  my ( $self, $lanes ) = @_;

  my $max = scalar @$lanes;
  my $progress_bar = Term::ProgressBar->new( {
    name   => 'finding files',
    count  => $max,
    remove => 1,
    ETA    => 'linear',
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
  $progress_bar->update($max)
    if ( defined $next_update and $max >= $next_update );

  return ( \@filenames, \@stats );
}

#-------------------------------------------------------------------------------

# creates a tar archive containing the specified files

sub _build_tar_archive {
  my ( $self, $filenames ) = @_;

  my $tar = Archive::Tar->new;

  my $max = scalar @$filenames;
  my $progress_bar = Term::ProgressBar->new( {
    name   => 'adding files',
    count  => $max,
    remove => 1,
    ETA    => 'linear',
    silent => $self->no_progress_bars,
  } );
  $progress_bar->minor(0); # ditch the "completion time estimator" character

  my $next_update = 0;
  for ( my $i = 0; $i < scalar @$filenames; $i++ ) {
    $tar->add_files($filenames->[$i]);
    $next_update = $progress_bar->update($i);
  }
  $progress_bar->update($max)
    if ( defined $next_update and $max >= $next_update );

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

  my $max = scalar @$filenames;
  my $next_update = 0;
  my $progress_bar = Term::ProgressBar->new( {
    name   => 'adding files',
    count  => $max,
    remove => 1,
    ETA    => 'linear',
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
    ETA    => 'linear',
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
    ETA    => 'linear',
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

