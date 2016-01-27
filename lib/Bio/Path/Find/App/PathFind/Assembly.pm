
package Bio::Path::Find::App::PathFind::Assembly;

# ABSTRACT: find assemblies

use v5.10; # for "say"

use MooseX::App::Command;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw( croak );
use Path::Class;

use Types::Standard qw(
  +Bool
);

use Bio::Path::Find::Types qw(
  PathClassDir  DirFromStr
  PathClassFile FileFromStr
  AssemblyType
);

use Bio::Path::Find::Exception;

extends 'Bio::Path::Find::App::PathFind';

#-------------------------------------------------------------------------------
#- usage text ------------------------------------------------------------------
#-------------------------------------------------------------------------------

# this is used when the "pf" app class builds the list of available commands
command_short_description 'Find genome assemblies';

=head1 NAME

pf assemblies - Find genome assemblies

=head1 USAGE

  pf assembly --id <id> --type <ID type> [options]

=head1 DESCRIPTION

The C<assembly> command finds accessions for samples. Search for data for by
specifying the type of data using the C<--type> option (C<lane>, C<sample>,
etc) and the ID using the C<--id> option.

=head1 EXAMPLES

  # get accessions for a set of lanes
  pf accession -t lane -i 10018_1

  # write accessions to a CSV file
  pf accession -t lane -i 10018_1 -o my_accessions.csv

  # get URLs for retrieving fastq files from the ENA FTP area
  pf accession -t lane -i 10018_1 -f fastq_urls.txt

  # get URLs for retrieving submitted files from the ENA FTP area
  pf accession -t lane -i 10018_1 -s submitted_file_urls.txt

=head1 OPTIONS

These are the options that are specific to C<pf accession>. Run C<pf man> to
see information about the options that are common to all C<pf> commands.

=over

=item --outfile, -o [<output filename>]

Write the accessions to a CSV-format file. If a filename is given, write info
to that file, or to C<accessionfind.csv> otherwise.

=item --fastq, -f [<output filename>]

Write a text file containing URLs for fastq files in the ENA. If a filename is
given, write to that file, or to C<fastq_urls.txt> otherwise.

=item --submitted, -s [<output filename>]

Write a text file containing URLs for submitted files in the ENA. If a filename
is given, write to that file, or to C<fsubmitted_urls.txt> otherwise.

=back

=head1 SCENARIOS

=head2 Show accessions

The C<pf accession> command prints four columns of data for each lane, showing
the following data for each sample:

=over

=item sample name

=item sample accession

=item lane name

=item lane accession

=back

  % pf accession -t lane -i 5477_6#1
  Sample name     Sample accession      Lane name           Lane accession
  Tw01_0055       ERS015862             5477_6#1            ERR028809

=head2 Write a CSV file

By default C<pf accession> simply prints the accessions that it finds. You can
write out a comma-separated values file (CSV) instead, using the C<--outfile>
(C<-o>) options:

  % pf accession -t lane -i 10018_1 -o my_accessions.csv
  Wrote accessions to "my_accessions.csv"

If you don't specify a filename, the default is C<accessionfind.csv>:

  % pf accession -t lane -i 10018_1 -o
  Wrote accessions to "accessionfind.csv"

=head2 Write a tab-separated file (TSV)

You can also change the separator used when writing out data. By default we
use comma (,), but you can change it to a tab-character in order to make the
resulting file more readable:

  pf accession -t lane -i 10018_1 -o -c "<tab>"

(To enter a tab character you might need to press ctrl-V followed by tab.)

=head2 Write a file of URLs for downloading data from ENA

By adding the C<-f> or C<-s> options, you can write out lists of URLs for
downloading fastq or submitted data files from ENA. Adding C<-f> will
write a file containing URLs for fastq files in the ENA FTP area:

  % pf accession -t lane -i 5477_6#1 -f
  Sample name     Sample accession      Lane name           Lane accession
  Tw01_0055       ERS015862             5477_6#1            ERR028809
  Wrote ENA URLs for fastq files to "fastq_urls.txt"

You can add a filename to save the URLs to a specific file:

  % pf accession -t lane -i 5477_6#1 -f my_urls.txt
  Sample name     Sample accession      Lane name           Lane accession
  Tw01_0055       ERS015862             5477_6#1            ERR028809
  Wrote ENA URLs for fastq files to "my_urls.txt"

Adding the C<-s> options will make pathfind write out a list of URLs for
data files that were submitted to the ENA:

  % pf accession -t lane -i 5477_6#1 -s
  Sample name     Sample accession      Lane name           Lane accession
  Tw01_0055       ERS015862             5477_6#1            ERR028809
  Wrote ENA URLs for submitted files to "submitted_urls.txt"

With either C<-f> or C<-s>, the accession information will still be printed,
unless you also add the C<-o> option. Adding C<-o> will send accessions to a
CSV file:

  % pf accession -t lane -i 5477_6#1 -f -o
  Wrote accessions to "accessionfind.csv"
  Wrote ENA URLs for fastq files to "fastq_urls.txt"

Note that if there are no fastq or submitted files for your samples, you will
see a warning message from pathfind:

  % pf accession -t lane -i 10018_1 -s -o
  Wrote accessions to "accessionfind.csv"
  No submitted files found in ENA; not writing file of URLs

=cut

#-------------------------------------------------------------------------------
#- command line options --------------------------------------------------------
#-------------------------------------------------------------------------------

option 'filetype' => (
  documentation => 'type of files to find',
  is            => 'ro',
  isa           => AssemblyType,
  cmd_aliases   => 'f',
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
  return file( getcwd(), $self->_renamed_id . '.assemblyfind_stats.csv' );
}

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# this is a builder for the "_lane_role" attribute that's defined on the parent
# class, B::P::F::A::PathFind. The return value specifies the name of a Role
# that should be applied to the B::P::F::Lane objects that are returned by the
# Finder.

sub _build_lane_role {
  return 'Bio::Path::Find::Lane::Role::Assembly';
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

sub run {
  my $self = shift;

  # Bio::Path::Find::Exception->throw( msg => q(ERROR: output file ") . $self->_outfile
  #                                    . q(" already exists; not overwriting) )
  #   if ( $self->_outfile_flag and -e $self->_outfile );
  #
  # Bio::Path::Find::Exception->throw( msg => q(ERROR: fastq URL output file ") . $self->_fastq
  #                                    . q(" already exists; not overwriting) )
  #   if ( $self->_fastq_flag and -e $self->_fastq );
  #
  # Bio::Path::Find::Exception->throw( msg => q(ERROR: submitted URL output file ") . $self->_submitted
  #                                    . q(" already exists; not overwriting) )
  #   if ( $self->_submitted_flag and -e $self->_submitted );

  # build the parameters for the finder. Omit undefined options or Moose spits
  # the dummy (by design)
  my %finder_params = (
    ids  => $self->_ids,
    type => $self->_type,
  );

  # find lanes
  my $lanes = $self->_finder->find_lanes(%finder_params);

  $self->log->debug( 'found ' . scalar @$lanes . ' lanes' );

  if ( scalar @$lanes < 1 ) {
    say STDERR 'No data found.';
    exit;
  }

  $DB::single = 1;

  my $filetype = $self->filetype || 'all';

  my $pb = $self->_build_pb('finding files', scalar @$lanes);

  foreach my $lane ( @$lanes ) {
    $lane->find_files($filetype);
    $pb++;
  }

  $_->print_paths for ( @$lanes );
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

