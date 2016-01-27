
package Bio::Path::Find::App::PathFind::Data;

# ABSTRACT: Find files and directories

use v5.10; # for "say"

use MooseX::App::Command;
use namespace::autoclean;
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

extends 'Bio::Path::Find::App::PathFind';

#-------------------------------------------------------------------------------
#- usage text ------------------------------------------------------------------
#-------------------------------------------------------------------------------

# this is used when the "pf" app class builds the list of available commands
command_short_description 'Find files and directories';

# the module POD is used when the users runs "pf man data"

=head1 NAME

pf data - Find files and directories

=head1 USAGE

  pf data --id <id> --type <ID type> [options]

=head1 DESCRIPTION

This pathfind command will output the path(s) on disk to the data associated
with sequencing run(s). Specify the type of data using C<--type> and give the
accession, name or identifier for the data using C<--id>.

You can search for data using several types of ID: lane, library, sample,
study, or species. B<Note> that searching using C<study> or C<species> can
produce a large number of results and can be very slow.

=head1 EXAMPLES

  # find the data directory containing files for a specific plex
  pf data -t lane -i 12345_1#1

  # find directories for lanes matching a lane name
  pf data -t lane -i 12345_1

  # find fastq files for a given plex
  pf data -t lane -i 12345_1#1 -f fastq

  # get statistics for a set of lanes
  pf data -t lane -i 12345_1 -s stats.csv

  # make symlinks to the data directory for a set of lanes
  pf data -t lane -i 12345_1 -l my_links_dir

  # make an tar archive of data for a lane (don't compress archive)
  pf data -t lane -i 12345_1#1 -a my_data.tar.gz -u

  # find data from a particular study
  pf data -t study -i my_study_name

=head1 OPTIONS

These are the options that are specific to C<pf data>. Run C<pf man> to see
information about the options that are common to all C<pf> commands.

=over

=item --qc, -q <status>

Filter results on QC status. Show only lanes with the specified QC status.
Status must be one of C<passed>, C<failed>, or C<pending>.

=item --stats, -s [<stats filename>]

Write a file with statistics about found lanes. Save to specified filename,
if given.

=item --symlink, -l [<symlink directory>]

Create symlinks to found data. Create links in the specified directory, if
given, or in the current working directory.

=item --archive, -a [<tar filename>]

Create a tar archive containing data files for found lanes. Save to specified
filename, if given.

=item --no-tar-compression, -u

Don't compress tar archives.

=item --zip, -z [<zip filename>]

Create a zip archive containing data files for found lanes. Save to specified
filename, if given.

=item --rename, -r

Rename filenames when creating archives or symlinks, replacing hashed (#)
with underscores (_).

=back

=head1 SCENARIOS

=head2 Finding files

The default behaviour for C<pf data> is to return the path to the directory
containing all data files for found lanes;

  pf data -t lane -i 12345_1

You can get the paths for data files by specifying the type of file to find
using the C<--filetype> option (C<--ft>):

  pf data -t lane -i 12345_1 --ft fastq

You can choose to find C<fastq>, C<bam>, C<corrected> or C<pacbio> files.

You can also filter the results to show only lanes with a specific QC status,
using the C<--qc> (C<-q>) option:

  pf data -t lane -i 12345_1 --qc passed

The C<-q> option accepts three values: C<passed>, C<failed>, and C<pending>.

=head2 Getting statistics

You can create a CSV file containing statistics for the found lanes, using the
C<--stats> (C<-s>) options. By default the file is named according to the
search term, e.g. C<12345_1.pathfind_stats.csv>, but you can give an argument
to C<-s> and specify the name of the stats file.

  pf data -t lane -i 12345_1 -s my_stats.csv

Note that you will see an error message if you try to write statistics to a
file that already exists.

=head2 Archiving data

The C<pf data> command can create a tar or zip archive for found data, using
the C<--archive> (C<-a>) or C<--zip> (C<-z>) options. If you have chosen to
find a specific filetype, using the C<--filetype> (C<--ft>) option, the archive
will contain that type of file. The default is to archive fastq files for your
found lanes.

The default behaviour is to create a gzip-compressed tar archive:

  pf data -t lane -i 12345_1 -a

which writes a file  named C<pathfind_12345_1.tar.gz>. You can specify you own
filename by adding it after the C<-a> option:

  pf data -t lane -i 12345_1 -a my_data.tar.gz

Note that compressing data files that are already compressed can be slow and
will not result in any significant space saving. You can choose to create
uncompressed tar archives using the C<--no-tar-compression> option (C<-u>):

  pf data -t lane -i 12345_1 -a my_data.tar -u

You can create a zip archive instead of a tar file using C<--zip> (C<-z>):

  pf data -t lane -i 12345_1 -z my_data.zip

Note that zip archives are always compressed.

By default, files in the archive are named as they are named in the
storage area. The original names contain hash characters (#), which can
cause problems in some situations, so you can opt to have the hashes
converted to underscores (_) using C<--rename> (C<-r>):

  pf data -t lane -i 12345_1 -a my_data.tar -u -r

Files may be renamed both when building the archive and when creating
symlinks (see below).

=head2 Creating symlinks

You can use C<pf data> to create links to your data in a directory of your
choice:

  pf data -t lane -i 12345_1 -l my_linked_data

If you do not specify a directory, the links are created in the current
working directory. You will get an error message if you do not have the
necessary permissions for creating files or links in the working directory.

As when creating archives, you can rename filenames when creating symlinks
using C<--rename> to convert hashes to underscores.

=cut

#-------------------------------------------------------------------------------
#- command line options --------------------------------------------------------
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

option 'no_tar_compression' => (
  documentation => "don't compress tar archives",
  is            => 'rw',
  isa           => Bool,
  cmd_flag      => 'no-tar-compression',
  cmd_aliases   => 'u',
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

has '_tar'      => ( is => 'rw', isa => PathClassFile );
has '_tar_flag' => ( is => 'rw', isa => Bool );

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

has '_zip'      => ( is => 'rw', isa => PathClassFile );
has '_zip_flag' => ( is => 'rw', isa => Bool );

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

has '_stats_flag' => ( is => 'rw', isa => Bool );
# has '_stats_file' => ( is => 'rw', isa => PathClassFile );

has '_stats_file' => (
  is      => 'rw',
  isa     => PathClassFile,
  lazy    => 1,
  builder => '_stats_file_builder',
);

sub _stats_file_builder {
  my $self = shift;
  return file( getcwd(), $self->_renamed_id . '.pathfind_stats.csv' );
}

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# this is a builder for the "_lane_role" attribute that's defined on the parent
# class, B::P::F::A::PathFind. The return value specifies the name of a Role
# that should be applied to the B::P::F::Lane objects that are returned by the
# Finder.

sub _build_lane_role {
  return 'Bio::Path::Find::Lane::Role::Data';
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

sub run {
  my $self = shift;

  # some quick checks that will allow us to fail fast if things aren't going to
  # let the command run to successfully

  if ( $self->_symlink_flag and          # flag is set; we're making symlinks.
       $self->_symlink_dir and           # destination is specified.
       -e $self->_symlink_dir and        # the destintation path exists.
       not -d $self->_symlink_dir ) {    # but it's not a directory.
    Bio::Path::Find::Exception->throw(
      msg => 'ERROR: symlink destination "' . $self->_symlink_dir
             . q(" exists but isn't a directory)
    );
  }

  if ( $self->_stats_flag and            # flag is set; we're writing stats.
       $self->_stats_file and            # destination file is specified.
       -e $self->_stats_file ) {         # output file already exists.
    Bio::Path::Find::Exception->throw(
      msg => 'ERROR: stats file "' . $self->_stats_file . q(" already exists)
    );
  }

  #---------------------------------------

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
  if ( $self->_symlink_flag or
       $self->_tar_flag or
       $self->_zip_flag or
       $self->_stats_flag ) {
    $self->_make_symlinks($lanes) if $self->_symlink_flag;
    $self->_make_tar($lanes)      if $self->_tar_flag;
    $self->_make_zip($lanes)      if $self->_zip_flag;
    $self->_make_stats($lanes)    if $self->_stats_flag;
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
  Bio::Path::Find::Exception->throw( msg => "ERROR: not a directory ($dest)" )
    unless -d $dest;

  say STDERR "Creating links in '$dest'";

  my $pb = $self->_build_pb('linking', scalar @$lanes);

  my $i = 0;
  foreach my $lane ( @$lanes ) {
    $lane->make_symlinks( dest => $dest, rename => $self->rename );
    $pb++;
  }
}

#-------------------------------------------------------------------------------

# make a tar archive of the data files for the found lanes

sub _make_tar {
  my ( $self, $lanes ) = @_;

  my $archive_filename;

  if ( $self->_tar ) {
    $self->log->debug('_tar attribute is set; using it as a filename');
    $archive_filename = $self->_tar;
  }
  else {
    $self->log->debug('_tar attribute is not set; building a filename');
    # we'll ALWAYS make a sensible name for the archive itself (use renamed_id)
    $archive_filename = 'pathfind_' . $self->_renamed_id
                        . ( $self->no_tar_compression ? '.tar' : '.tar.gz' );
  }
  $archive_filename = file $archive_filename;

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

  # gzip compress the archive ?
  my $output = $self->no_tar_compression
             ? $tar_contents
             : $self->_compress_data($tar_contents);

  # and write it out, gzip compressed
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

  my $archive_filename;

  if ( $self->_zip ) {
    $self->log->debug('_zip attribute is set; using it as a filename');
    $archive_filename = $self->_zip;
  }
  else {
    $self->log->debug('_zip attribute is not set; building a filename');
    # we'll ALWAYS make a sensible name for the archive itself (use renamed_id)
    $archive_filename = 'pathfind_' . $self->_renamed_id . '.zip';
  }
  $archive_filename = file $archive_filename;

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
  my $zip = $self->_build_zip_archive($filenames);

  print STDERR 'Writing zip file... ';

  # write it to file
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

  my $pb = $self->_build_pb('finding files', scalar @$lanes);

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

    $pb++;
  }

  return ( \@filenames, \@stats );
}

#-------------------------------------------------------------------------------

# creates a tar archive containing the specified files

sub _build_tar_archive {
  my ( $self, $filenames ) = @_;

  my $tar = Archive::Tar->new;

  my $pb = $self->_build_pb('adding files', scalar @$filenames);

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

sub _build_zip_archive {
  my ( $self, $filenames ) = @_;

  my $zip = Archive::Zip->new;

  my $pb = $self->_build_pb('adding files', scalar @$filenames);

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

  $DB::single = 1;

  my $max        = length $data;
  my $num_chunks = 100;
  my $chunk_size = int( $max / $num_chunks );

  # set up the progress bar
  my $pb = $self->_build_pb('gzipping', $num_chunks);

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

  my $max        = length $data;
  my $num_chunks = 100;
  my $chunk_size = int( $max / $num_chunks );

  my $pb = $self->_build_pb('writing', $num_chunks);

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

# build a CSV file with the statistics for all lanes and write it to file

sub _make_stats {
  my ( $self, $lanes ) = @_;

  # collect the stats for the supplied lanes
  my @stats = (
    $lanes->[0]->stats_headers,
  );

  my $pb = $self->_build_pb('collecting stats', scalar @$lanes);

  foreach my $lane ( @$lanes ) {
    push @stats, $lane->stats;
    $pb++;
  }

  $self->_write_csv(\@stats, $self->_stats_file);
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

