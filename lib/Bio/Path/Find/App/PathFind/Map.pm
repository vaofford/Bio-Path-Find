
package Bio::Path::Find::App::PathFind::Map;

# ABSTRACT: Find mapped bam files for lanes

use v5.10; # for "say"

use MooseX::App::Command;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw ( carp );
use Path::Class;
use Try::Tiny;

use Types::Standard qw(
  ArrayRef
  Str
  +Bool
);

use Bio::Path::Find::Types qw( :types MappersFromMapper );

use Bio::Path::Find::Lane::Class::Map;
use Bio::Path::Find::Lane::StatusFile;

extends 'Bio::Path::Find::App::PathFind';

with 'Bio::Path::Find::App::Role::Archivist',
     'Bio::Path::Find::App::Role::Linker',
     'Bio::Path::Find::App::Role::Statistician';

#-------------------------------------------------------------------------------
#- usage text ------------------------------------------------------------------
#-------------------------------------------------------------------------------

# this is used when the "pf" app class builds the list of available commands
command_short_description 'Find mapped bam files for lanes';

# the module POD is used when the users runs "pf man info"

=head1 NAME

pf info - Find mapped bam files for lanes

=head1 USAGE

  pf map --id <id> --type <ID type> [options]

=head1 DESCRIPTION

This pathfind command will return information about samples associated with
sequencing runs. Specify the type of data using C<--type> and give the
accession, name or identifier for the data using C<--id>.

Use "pf man" or "pf man info" to see more information.

=head1 EXAMPLES

  # get sample info for a set of lanes
  pf info -t lane -i 10018_1

  # write info to a CSV file
  pf info -t lane -i 10018_1 -o info.csv

=head1 OPTIONS

These are the options that are specific to C<pf info>. Run C<pf man> to see
information about the options that are common to all C<pf> commands.

=over

=item --outfile, -o [<output filename>]

Write the information to a CSV-format file. If a filename is given, write info
to that file, or to C<infofind.csv> otherwise.

=back

=head1 SCENARIOS

=head2 Show info about samples

The C<pf info> command prints five columns of data for each lane, showing data
about each sample from the tracking and sequencescape databases:

=over

=item lane

=item sample

=item supplier name

=item public name

=item strain

=back

=head2 Write a CSV file

By default C<pf info> simply prints the data that it finds. You can write out a
comma-separated values file (CSV) instead, using the C<--outfile> (C<-o>)
options:

  % pf info -t lane -i 10018_1 -o my_info.csv
  Wrote info to "my_info.csv"

If you don't specify a filename, the default is C<infofind.csv>:

  % pf info -t lane -i 10018_1 -o
  Wrote info to "infofind.csv"

=head2 Write a tab-separated file (TSV)

You can also change the separator used when writing out data. By default we
use comma (,), but you can change it to a tab-character in order to make the
resulting file more readable:

  pf info -t lane -i 10018_1 -o -c "<tab>"

(To enter a tab character you might need to press ctrl-V followed by tab.)

=cut

#-------------------------------------------------------------------------------
#- command line options --------------------------------------------------------
#-------------------------------------------------------------------------------

option 'details' => (
  documentation => 'show details for each mapping run',
  is            => 'ro',
  isa           => Bool,
  cmd_aliases   => 'D',
);

#---------------------------------------

option 'qc' => (
  documentation => 'filter results by lane QC state',
  is            => 'ro',
  isa           => QCState,
  cmd_aliases   => 'q',
);

#---------------------------------------

option 'reference' => (
  documentation => 'show lanes that were mapped against a specific reference',
  is            => 'ro',
  isa           => Str,
  cmd_aliases   => 'R',
);

#---------------------------------------

option 'mapper' => (
  documentation => 'show assemblies mapped with specific mapper(s)',
  is            => 'rw',
  isa           => Mappers,
  cmd_aliases   => 'M',
  cmd_split     => qr/,/,
);

#---------------------------------------

# this is an attribute, not an option, because we don't want it to be settable
# by the user. This command only finds bam files.

has 'filetype' => (
  is      => 'ro',
  isa     => MapType,
  default => 'bam',
);

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# this is a builder for the "_lane_class" attribute, which is defined on the
# parent class, B::P::F::A::PathFind. The return value specifies the class of
# object that should be returned by the B::P::F::Finder::find_lanes method.

sub _build_lane_class {
  return 'Bio::Path::Find::Lane::Class::Map';
}

#---------------------------------------

# this is a builder that sets the name of the stats output file
#
# overrides a method in the Statistician Role

sub _build_stats_file {
  my $self = shift;
  return file( $self->_renamed_id . '.mapping_stats.csv' );
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

sub run {
  my $self = shift;

  # TODO fail fast if we're going to overwrite something

  # build the parameters for the finder
  my %finder_params = (
    ids      => $self->_ids,
    type     => $self->type,
    filetype => 'bam',  # triggers a call to B::P::F::Lane::Class::Map::_get_bam
  );                    # for file finding

  #---------------------------------------

  # these are filters that are applied by the finder

  # when finding lanes, should the finder filter on QC status ?
  $finder_params{qc} = $self->qc if $self->qc;

  # should we look for lanes with the "mapped" bit set on the "processed" bit
  # field ? Turning this off, i.e. setting the command line option
  # "--ignore-processed-flag" will allow the command to return data for lanes
  # that haven't completed the mapping pipeline.
  $finder_params{processed} = Bio::Path::Find::Types::MAPPED_PIPELINE
    unless $self->ignore_processed_flag;

  #---------------------------------------

  # these are filters that are applied by the lanes themselves, when they're
  # finding files to return (see "B::P::F::Lane::Class::Map::_get_bam")

  # when finding files, should the lane restrict the results to files created
  # with a specified mapper ?
  $finder_params{lane_attributes}->{mappers} = $self->mapper
    if $self->mapper;

  # when finding files, should the lane restrict the results to mappings
  # against a specific reference ?
  $finder_params{lane_attributes}->{reference} = $self->reference
    if $self->reference;

  #---------------------------------------

  # find lanes
  my $lanes = $self->_finder->find_lanes(%finder_params);

  if ( scalar @$lanes < 1 ) {
    say STDERR 'No data found.';
    return;
  }

  # should we write out a stats file ?
  $self->_make_stats($lanes) if $self->_stats_flag;

  # print the list of files. Should we show extra info ?
  if ( $self->details ) {
    # yes; print file path, reference, mapper and timestamp
    $_->print_details for @$lanes;
  }
  else {
    # no; just print the paths
    $_->print_paths   for @$lanes;
  }
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

