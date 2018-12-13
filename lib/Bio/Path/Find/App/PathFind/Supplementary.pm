
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

=item --description, -d

Include sample description in the supplementary information.

=back

=head1 SCENARIOS

=head2 Show supplementary information about samples

The C<pf supplementary > command prints nine columns of data for each lane, 
showing study information, accessions and metadata for each sample from the 
tracking and sequencescape databases:

=over

=item sample name

=item sample accession

=item lane name

=item lane accession

=item supplier name

=item public name

=item strain

=item study id

=item study accession

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

=head2 Include sample descriptions

By default C<pf supplementary > will not include sample descriptions. You 
can include sample descriptions in the output, using the 
C<--description> (C<-d>) option:

  % pf supplementary  -t lane -i 10018_1 -d

=head1 SEE ALSO

=over

=item pf accession - find accessions for sequencing runs

=item pf info - find information about samples

=back

=cut

#-------------------------------------------------------------------------------
#- command line options --------------------------------------------------------
#-------------------------------------------------------------------------------

# private attributes to store the (optional) value of the "outfile" attribute.
# When using all of this we can check for "_outfile_flag" being true or false,
# and, if it's true, check "_outfile" for a value
has '_outfile'      => ( is => 'rw', isa => PathClassFile, default => sub { file 'supplementaryfind.csv' } );

# Boolean for sample description inclusion
option 'description' => (
  documentation => 'include sample description',
  is            => 'ro',
  isa           => Bool,
  cmd_aliases   => 'd',
  cmd_flag      => 'description',
  default       => 0,
);

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------


sub _get_study_info {
  my $self = $_[0];
  my $lane = $_[1];

  # Get study ssid from pathogen database
  my $study_ssid = $lane->row
                      ->latest_library
                        ->latest_sample
                          ->latest_project
                            ->ssid;

  # Get study name from pathogen database
  my $study_name = $lane->row
                      ->latest_library
                        ->latest_sample
                          ->latest_project
                            ->name;

  # and get the corresponding row in sequencescape_warehouse.current_study
  my $row = $self->_ss_db
                     ->schema
                       ->resultset('CurrentStudy')
                         ->find( { internal_id => $study_ssid  } );

  my @study_info = [
                    defined($row) && $row->name eq $study_name ? ($row->internal_id || 'NA') : 'NA',
                    defined($row) && $row->name eq $study_name ? ($row->accession_number || 'NA') : 'NA',
#                    defined($row) && $row->name eq $study_name ? ($row->name || 'NA') : 'NA',
                  ];

  return @study_info;
}

sub _get_sample_description {
  my $self = $_[0];
  my $lane = $_[1];

  my $current_sample = $self->_get_current_sample($lane);
  my $study_name = $self->_get_sample_name($lane);
  my $sample_description = $current_sample->description, if defined($current_sample) && $current_sample->name eq $study_name;
  $sample_description = 'NA' unless defined $sample_description;
  return $sample_description;
}

#-------------------------------------------------------------------------------

sub _get_supplementary_info {
  my $self = $_[0];
  my $lane = $_[1];

  my @lane_info = $self->_get_lane_info($lane);
  my $af = Bio::Path::Find::App::PathFind::Accession->new(id => $lane->row->name, type => 'lane');
  my @accession_info = $af->_get_accession_info($lane);
  my @study_info = $self->_get_study_info($lane);

  my @supplementary_info =  [
                              @{ $accession_info[0] },
                              $lane_info[0]->[2], 
                              $lane_info[0]->[3],
                              $lane_info[0]->[4],
                              @{ $study_info[0] }
                            ];  

  if ( $self->description ) {
    my $sample_description = $self->_get_sample_description($lane);
    push @{ $supplementary_info[0] }, $sample_description; 
  }                          
           
  return @supplementary_info;
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

sub run {
  my $self = shift;

  # if we're writing to file, check that the output file doesn't exist. If we
  # leave it to _write_csv to check, we could end up searching for lanes for
  # hours and THEN fail, which would leave the user mildly updset. Better to
  # fail early, before we've done any work at all.
  if ( $self->_outfile_flag and -f $self->_outfile and not $self->force ) {
    Bio::Path::Find::Exception->throw(
      msg => q(ERROR: CSV file ") . $self->_outfile . q(" already exists; not overwriting existing file)
    );
  }

  # find lanes
  my $lanes = $self->_finder->find_lanes(
    ids  => $self->_ids,
    type => $self->_type,
  );

  my $pb = $self->_create_pb('collecting supplementary info', scalar @$lanes);

  # gather the info. We could collect and print the info in the same loop, but
  # then we wouldn't be able to show the progress bar, which is probably worth
  # doing. Instead we'll print in a separate loop at the end.

  # start with headers
  my @info = (
    [ 'Sample Name', 'Sample Acc', 
      'Lane Name', 'Lane Acc',
      'Supplier Name', 'Public Name', 'Strain', 
      'Study ID', 'Study Accession' 
    ]
  );  
  push @{ $info[0] }, 'Sample Description' if ( $self->description );  

  foreach my $lane ( @$lanes ) {
    my @supplementary_info = $self->_get_supplementary_info($lane);
    push @info, @supplementary_info;
    $pb++;
  }

  # write a CSV file or print to STDOUT
  if ( $self->_outfile_flag ) {
    $self->_write_csv( \@info, $self->_outfile );
    say STDERR q(Wrote supplememtary information to ") . $self->_outfile . q(");
  }
  else {
    # fix the formats of the columns so that everything lines up
    # (printf format patterned on the one from the old infofind;
    # ditched the trailing spaces...)
    if ( $self->description) {
      printf "%-25s %-15s %-15s %-15s %-25s %-25s %-25s %-15s %-15s %s\n", @$_ for @info;
    } else {
      printf "%-25s %-15s %-15s %-15s %-25s %-25s %-25s %-15s %s\n", @$_ for @info;
    }
  }

}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;
