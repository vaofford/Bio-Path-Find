
package Bio::Path::Find::App::PathFind::Assembly;

# ABSTRACT: find assemblies

use v5.10; # for "say"

use MooseX::App::Command;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw( croak );
use Path::Class;
use Cwd;

use Types::Standard qw(
  +Bool
);

use Bio::Path::Find::Types qw(
  PathClassDir  DirFromStr
  PathClassFile FileFromStr
  AssemblyType
  Assembler
);

use Bio::Path::Find::Exception;

extends 'Bio::Path::Find::App::PathFind';

with 'Bio::Path::Find::Role::Linker',
     'Bio::Path::Find::Role::Archiver',
     'Bio::Path::Find::Role::Statistician';

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
  default       => 'scaffold',
);

#---------------------------------------

option 'program' => (
  documentation => 'look for assemblies created by a specific assembler',
  is            => 'ro',
  isa           => Assembler,
  cmd_aliases   => 'p',
);

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

#---------------------------------------

# this is a builder for the "_stats_file" attribute that's defined by the
# B::P::F::Role::Statistician. This attribute provides the default name of the
# stats file that the command writes out

sub _stats_file_builder {
  my $self = shift;
  return file( getcwd(), $self->_renamed_id . '.assemblyfind_stats.csv' );
}

#---------------------------------------

# set the default name for the symlink directory

around '_build_symlink_dir' => sub {
  my $orig = shift;
  my $self = shift;

  my $dir = $self->$orig->stringify;
  $dir =~ s/^pf_/assemblyfind_/;

  return dir( $dir );
};

#---------------------------------------

# set the default names for the tar or zip files

around [ '_build_tar_filename', '_build_zip_filename' ] => sub {
  my $orig = shift;
  my $self = shift;

  my $filename = $self->$orig->stringify;
  $filename =~ s/^pf_/assemblyfind_/;

  return file( $filename );
};

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

sub run {
  my $self = shift;

  # TODO fail fast. Check for problems like existing directories here, before
  # TODO actually doing any work

  # set up the finder

  # build the parameters for the finder
  my %finder_params = (
    ids      => $self->_ids,
    type     => $self->_type,
    filetype => $self->filetype,    # defaults to "scaffold"
  );

  # should we restrict the search to a specific assembler ?
  if ( $self->program ) {
    $self->log->debug( 'finding lanes with assemblies created by ' . $self->program );

    # yes; tell the Finder to set the "assemblers" attribute on every Lane that
    # it returns
    $finder_params{lane_attributes}->{assemblers} = [ $self->program ];
  }

 # find lanes
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
    # we've set a default ("scaffold") for the "filetype" on the Finder, so
    # when it looks for lanes it will automatically tell each lane to find
    # files of type "scaffold". Hence, "print_paths" will print the paths for
    # those found files.
    $_->print_paths for ( @$lanes );
  }

}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

