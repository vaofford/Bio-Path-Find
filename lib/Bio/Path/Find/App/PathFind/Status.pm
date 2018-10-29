
package Bio::Path::Find::App::PathFind::Status;

# ABSTRACT: Find the status of samples

use v5.10; # for "say"

use MooseX::App::Command;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Path::Class;
use Text::Table;

use Types::Standard qw(
  +Bool
);

use Bio::Path::Find::Types qw( :types );

extends 'Bio::Path::Find::App::PathFind';

#-------------------------------------------------------------------------------
#- usage text ------------------------------------------------------------------
#-------------------------------------------------------------------------------

# this is used when the "pf" app class builds the list of available commands
command_short_description 'Find the status of samples';

# the module POD is used when the users runs "pf man status"

=head1 NAME

pf status - Find the status of samples

=head1 USAGE

  pf status --id <id> --type <ID type> [options]

=head1 DESCRIPTION

The status command will return information about the status of samples in the
various pathogen informatics pipelines. Search for lanes by specifying the type
of data using C<--type> and give the accession, name or identifier for the data
using C<--id>.

Use "pf man" or "pf man status" to see more information.

=head1 EXAMPLES

  # get the status of a set of lanes as a simple table
  pf status -t lane -i 12345_1

  # show the status of a set of lanes, taking lane IDs from a file
  pf status -t file --ft lane -i my_ids.txt

  # show the status of a all lanes from a specific study
  pf status -t study -i 'My study name'

  # write status information to a CSV file
  pf status -t lane -i 12345_1 -o status_info.csv

=head1 PIPELINE STATUS VALUES

The C<pf status> command prints the status for each found lane for 9 key
pathogen informatics pipelines:

=over

=item Import

=item QC

=item Mapping

=item Archive

=item Improve

=item SNP call

=item RNASeq

=item Assemble

=item Annotate

=back

The status of a sample in each pipeline is given as:

=over

=item Done

=item Running

=item Failed

=item Pending

=back

Unless the status is C<Done>, the output also shows the date at which the
status was changed to the current value.

=head1 OPTIONS

These are the options that are specific to C<pf status>. Run C<pf man> to see
information about the options that are common to all C<pf> commands.

=over

=item --outfile, -o [<output filename>]

Write status information to a CSV-format file. If a filename is given, write
info to that file, or to C<statusfind.csv> otherwise. If the output file
already exists, the script will print a warning and stop. To force it to
overwrite an existing file, add C<-F>.

=back

=head1 SCENARIOS

=head2 Show status information for a collection of samples

In the simplest case, C<pf status> shows a table giving the name of a lane
and its status across the 9 pipelines:

  % pf status -t lane -i 12345_1
  Name       Import QC                   Mapping Archive Improve SNP call RNASeq Assemble Annotate
  12345_1#1  Done   Done                 Done    Done    -       -        -      -        -
  12345_1#2  Done   Running (22-02-2016) -       -       -       -        -      -        -

This output shows the status of two lanes, the first of which has run
successfully through the import, QC, mapping and archival pipelines. The
second lane has been imported and started running through the QC pipeline
on 22nd Feb 2016.

=head2 Write a CSV file

By default C<pf status> simply prints the status informat that it finds. You
can write out a comma-separated values file (CSV) instead, using the
C<--outfile> (C<-o>) option:

  % pf status -t lane -i 12345_1 -o my_status_info.csv
  Wrote status information to "my_status_info.csv"

If you don't specify a filename, the default is C<statusfind.csv>:

  % pf status -t lane -i 12345_1 -o
  Wrote status information to "statusfind.csv"

If the output file exists, the command will exit with an error. Force
overwriting of an existing file by adding the C<-F> option.

=head2 Write a tab-separated file (TSV)

You can also change the separator used when writing out data. By default we
use comma (,), but you can change it to a tab-character in order to make the
resulting file more readable:

  pf status -t lane -i 12345_1 -o -c "<tab>"

(To enter a tab character you might need to press ctrl-V followed by tab.)

=head1 SEE ALSO

=over

=item pf data - find data files

=item pf info - find information about samples

=back

=cut

#-------------------------------------------------------------------------------
#- command line options --------------------------------------------------------
#-------------------------------------------------------------------------------

# this option can be used as a simple switch ("-o") or with an argument
# ("-o mydir"). It's a bit fiddly to set that up...

option 'outfile' => (
  documentation => 'write info to a CSV file',
  is            => 'ro',
  cmd_aliases   => 'o',
  cmd_env       => 'PF_OUTFILE',
  trigger       => \&_check_for_outfile_value,
  # no "isa" because we want to accept both Bool and Str and it doesn't seem to
  # be possible to specify that using the combination of MooseX::App and
  # Type::Tiny that we're using here
);

# set up a trigger that checks for the value of the "outfile" command-line
# argument and tries to decide if it's a boolean, in which case we'll generate
# a filename, or a string, in which case we'll treat that string as a filename.
sub _check_for_outfile_value {
  my ( $self, $new, $old ) = @_;

  if ( not defined $new ) {
    # write info to file specified by the user
    $self->_outfile_flag(1);
  }
  elsif ( not is_Bool($new) ) {
    # write info to file specified by the user
    $self->_outfile_flag(1);
    $self->_outfile( file $new );
  }
  else {
    # don't write file. Shouldn't ever get here
    $self->_outfile_flag(0);
  }
}

# private attributes to store the (optional) value of the "outfile" attribute.
# When using all of this we can check for "_outfile_flag" being true or false,
# and, if it's true, check "_outfile" for a value
has '_outfile'      => ( is => 'rw', isa => PathClassFile, default => sub { file 'statusfind.csv' } );
has '_outfile_flag' => ( is => 'rw', isa => Bool );

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

  my $pb = $self->_create_pb('collecting info', scalar @$lanes);

  # the column headers
  my @info = (
    [ 'Name', 'Import', 'QC', 'Mapping', 'Archive', 'Improve', 'SNP call', 'RNASeq', 'Assemble', 'Annotate' ],
  );

  # the status of each lane for the specified pipelines
  foreach my $lane ( @$lanes ) {
    push @info, [
      $lane->row->name,
      $lane->status->pipeline_status('import'),
      $lane->status->pipeline_status('qc'),
      $lane->status->pipeline_status('mapped'),
      $lane->status->pipeline_status('stored'),
      $lane->status->pipeline_status('improved'),
      $lane->status->pipeline_status('snp_called'),
      $lane->status->pipeline_status('rna_seq_expression'),
      $lane->status->pipeline_status('assembled'),
      $lane->status->pipeline_status('annotated'),
    ];

    $pb++;
  }

  # write the status information as a CSV file or print to STDOUT ?

  if ( $self->_outfile_flag ) {
    # write a CSV file
    $self->_write_csv( \@info, $self->_outfile );
    say STDERR q(Wrote status information to ") . $self->_outfile . q(");
  }
  else {
    # print as a simple table

    # the first row of the @info array contains a reference to the array that
    # holds column headers. Shift off that array and de-reference it so that we
    # pass an array to Text::Table
    my $headers = shift @info;
    my $tt = Text::Table->new( @$headers );

    # and, having shifted off the first row, the rest of @info is the
    # data that we can drop straight into the output table
    $tt->load(@info);

    print $tt;
  }

}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

