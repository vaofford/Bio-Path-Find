
package Bio::Path::Find::App::PathFind::Ref;

# ABSTRACT: Find reference genones

use v5.10; # for "say"

use MooseX::App::Command;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw ( carp );
use Path::Class;
use Try::Tiny;
use Bio::Path::Find::RefFinder;

use Data::Printer;

use Types::Standard qw(
  ArrayRef
  Str
  +Bool
);

use Bio::Path::Find::Types qw( :types );

extends 'Bio::Path::Find::App::PathFind';

with 'Bio::Path::Find::App::Role::Archivist',
     'Bio::Path::Find::App::Role::Linker';

#-------------------------------------------------------------------------------
#- usage text ------------------------------------------------------------------
#-------------------------------------------------------------------------------

# this is used when the "pf" app class builds the list of available commands
command_short_description 'Find reference genomes';

# the module POD is used when the users runs "pf man info"

=head1 NAME

pf info - Find information about samples

=head1 USAGE

  pf info --id <id> --type <ID type> [options]

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

# we don't actually need the "--type" option for reffind, since all we're ever
# going to be looking for is species names. Override the default value of
# "required", to make this an optional parameter with this command

option '+type' => (
  required => 0,
);

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

has '_rf' => (
  is      => 'ro',
  isa     => BioPathFindRefFinder,
  builder => '_build_rf',
);

sub _build_rf {
  return Bio::Path::Find::RefFinder->new;
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

sub run {
  my $self = shift;

  my $paths = $self->_rf->find_paths('yersina');

  p $paths;
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

