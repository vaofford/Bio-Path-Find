
package Bio::Path::Find::App::PathFind::Supplementary;

# ABSTRACT: Get supplementary information about samples

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

use Bio::Path::Find::Types qw( :types );

use Bio::Path::Find::App::PathFind::Accession;

extends 'Bio::Path::Find::App::PathFind::Info';

#-------------------------------------------------------------------------------
#- usage text ------------------------------------------------------------------
#-------------------------------------------------------------------------------

# this is used when the "pf" app class builds the list of available commands
command_short_description 'Get supplementary information about samples';

# the module POD is used when the users runs "pf man supplementary"

=head1 NAME

pf supplementary - Find supplementary information about samples

=head1 USAGE

  pf supplementary --id <id> --type <ID type> [options]

=head1 DESCRIPTION

This pathfind command will return supplementary information about samples 
associated with sequencing runs including study information, accessions and 
sample metadata. Specify the type of data using C<--type> and give the
accession, name or identifier for the data using C<--id>.

Use "pf man" or "pf man supplementary" to see more information.

=head1 EXAMPLES

  # get supplementary information for a set of lanes
  pf supplementary -t lane -i 10018_1

  # write supplementary information to a CSV file
  pf supplementary -t lane -i 10018_1 -o supplementary.csv

=head1 OPTIONS

These are the options that are specific to C<pf supplementary>. Run C<pf man> 
to see information about the options that are common to all C<pf> commands.

=over

=item --outfile, -o [<output filename>]

Write the information to a CSV-format file. If a filename is given, write 
supplementary information to that file, or to C<supplementaryfind.csv> otherwise.

=back

=head1 SCENARIOS

=head2 Show supplementary information about samples

The C<pf supplementary > command prints nine columns of data for each lane, 
showing study information, accessions and metadata for each sample from the 
tracking and sequencescape databases:

=over

=item study id

=item study accession

=item sample name

=item sample accession

=item supplier name

=item public name

=item strain

=item lane name

=item lane accession

=item strain

=back

=head2 Write a CSV file

By default C<pf supplementary > simply prints the data that it finds. You 
can write out a comma-separated values file (CSV) instead, using the 
C<--outfile> (C<-o>) options:

  % pf supplementary  -t lane -i 10018_1 -o my_supplementary_info.csv
  Wrote supplementary information to "my_supplementary_info.csv"

If you don't specify a filename, the default is C<supplementaryfind.csv>:

  % pf supplementary -t lane -i 10018_1 -o
  Wrote supplementary information to "supplementaryfind.csv"

=head2 Write a tab-separated file (TSV)

You can also change the separator used when writing out data. By default we
use comma (,), but you can change it to a tab-character in order to make the
resulting file more readable:

  pf supplementary -t lane -i 10018_1 -o -c "<tab>"

(To enter a tab character you might need to press ctrl-V followed by tab.)

=head1 SEE ALSO

=over

=item pf accession - find accessions for sequencing runs

=item pf status - pf info - find information about samples

=back

=cut

#-------------------------------------------------------------------------------
#- command line options --------------------------------------------------------
#-------------------------------------------------------------------------------

# None at the moment, inherits from pf info

#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;
