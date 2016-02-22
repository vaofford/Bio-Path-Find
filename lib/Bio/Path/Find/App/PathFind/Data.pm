
package Bio::Path::Find::App::PathFind::Data;

# ABSTRACT: Find files and directories

use v5.10; # for "say"

use MooseX::App::Command;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Path::Class;
use Cwd;

use Bio::Path::Find::Types qw( :types );

use Bio::Path::Find::Exception;
use Bio::Path::Find::Lane::Class::Data;

extends 'Bio::Path::Find::App::PathFind';

with 'Bio::Path::Find::App::Role::Linker',
     'Bio::Path::Find::App::Role::Archivist',
     'Bio::Path::Find::App::Role::Statistician';

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
  isa           => DataType,
  cmd_aliases   => 'f',
);

option 'qc' => (
  documentation => 'filter results by lane QC state',
  is            => 'ro',
  isa           => QCState,
  cmd_aliases   => 'q',
);

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# this is a builder for the "_lane_class" attribute, which is defined on the
# parent class, B::P::F::A::PathFind. The return value specifies the name of
# the class that should be returned by the B::P::F::Finder::find_lanes method.

sub _build_lane_class {
  return 'Bio::Path::Find::Lane::Class::Data';
}

#---------------------------------------

# this is a builder for the "_stats_file" attribute that's defined by the
# B::P::F::Role::Statistician. This attribute provides the default name of the
# stats file that the command writes out

sub _build_stats_file {
  my $self = shift;
  return file( getcwd(), $self->_renamed_id . '.pathfind_stats.csv' );
}

#---------------------------------------

# set the default name for the symlink directory

around '_build_symlink_dir' => sub {
  my $orig = shift;
  my $self = shift;

  my $dir = $self->$orig->stringify;
  $dir =~ s/^pf_/pathfind_/;

  return dir( $dir );
};

#---------------------------------------

# set the default names for the tar or zip files

around [ '_build_tar_filename', '_build_zip_filename' ] => sub {
  my $orig = shift;
  my $self = shift;

  my $filename = $self->$orig->stringify;
  $filename =~ s/^pf_/pathfind_/;

  return file( $filename );
};

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

  if ( not $self->force and              # we're not overwriting stuff.
       $self->_stats_flag and            # flag is set; we're writing stats.
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

  # should we filter on QC status ?
  $finder_params{qc} = $self->qc if defined $self->qc;

  # if the user specifies a filetype, tell the finder to search for that type
  # of file...
  if ( $self->filetype ) {
    $finder_params{filetype} = $self->filetype;
  }
  # if we're archiving but there was no specified filetype, collect fastq files
  # by default
  else {
    if ( $self->_tar_flag or $self->_zip_flag ) {
      $finder_params{filetype} = 'fastq';
    }
  }

  # actually go and find lanes
  my $lanes = $self->_finder->find_lanes(%finder_params);

  $self->log->debug( 'found a total of ' . scalar @$lanes . ' lanes' );

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
    # telling B::P::F::Finder to look for files of a specific type will make
    # it run $lane->find_files, so calling $lane->print_paths will print out
    # the names of the found files.
    # If we don't tell Finder to look for files, $lane->print_path will fall
    # back to printing the directory name for a lane
    $_->print_paths for ( @$lanes );
  }

}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

