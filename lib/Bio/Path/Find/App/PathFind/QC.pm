
package Bio::Path::Find::App::PathFind::QC;

# ABSTRACT: Find quality control information about samples

use v5.10; # for "say"

use MooseX::App::Command;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Bio::Metagenomics::External::KrakenSummary;
use Path::Class;
use Text::CSV_XS;

use Types::Standard qw(
  +Bool
);

# use Bio::Path::Find::Types qw( :types );
use Bio::Path::Find::Types qw( :types LevelCodeFromName );

use Bio::Path::Find::Lane::Class::QC;

extends 'Bio::Path::Find::App::PathFind';

with 'Bio::Path::Find::App::Role::Archivist',
     'Bio::Path::Find::App::Role::Linker';

#-------------------------------------------------------------------------------
#- usage text ------------------------------------------------------------------
#-------------------------------------------------------------------------------

# this is used when the "pf" app class builds the list of available commands
command_short_description 'Find quality control information about samples';

# the module POD is used when the users runs "pf man qc"

=head1 NAME

pf qc - Find quality control information about samples

=head1 USAGE

  pf qc --id <id> --type <ID type> [options]

=head1 DESCRIPTION

The C<qc> command will return quality control data. Specify the type of data
using C<--type> and give the accession, name or identifier for the data using
C<--id>.

Use "pf man" or "pf man qc" to see more information.

=head1 EXAMPLES

  # find QC reports for a set of lanes
  pf qc -t lane -i 12345_1

  # write a summary of the QC data
  pf qc -t lane -i 12345_1 -s

  # create an archive of kraken reports for lanes from a particular study
  pf qc -t study -i 123 -a study_123_reports.tar.gz

=head1 OPTIONS

These are the options that are specific to C<pf qc>. Run C<pf man> to see
information about the options that are common to all C<pf> commands.

=over

=item --summary, -s [<output filename>]

Write a CSV file with a summary of the kraken reports for the found lanes. If a
filename is given, the summary will be writen to that file, or to
C<qc_summary.csv> otherwise.

=item --counts, -C

Use counts in the summary, rather than percentages.

=item --directly, -d

Report reads assigned directly to this taxon.

=item --level, -L <taxonomic level>

Output information for the specified taxonomic level. The level must be one of
the following values, or its abbreviation: C<domain> (abbreviation C<D>),
C<phylum> (C<P>), C<class> (C<C>), C<order> (C<O>), C<family> (C<F>), C<genus>
(C<G>), C<species> (C<S>), C<strain> (C<T>). The default level is C<strain>.

=back

=head1 SCENARIOS

=head2 Show QC info about samples

By default, the C<pf qc> command simply prints the paths for the kraken reports
for all of the lanes that it finds:

  pf qc -t lane -i 12345_1

You can archive those kraken reports, as a tar file

  pf qc -t lane -i 12345_1 -a

or a zip file:

  pf qc -t lane -i 12345_1 -z lanes_qc.zip

or you can create links to them in the current directory:

  pf qc -t lane -i 12345_1 -l

or in a different directory:

  pf qc -t study -i 123 -l study_123_qc_reports

=head2 Write a summary CSV file

You can generate a single summary file, based on data from the kraken reports
for all of the found lanes, using C<--summary> (abbreviated to C<-s>):

  pf qc -t lane -i 12345_1 -s

There are several options that affect the exact format of the summary report.

By default, the summary uses percentages, but you can also see the counts for
the individual taxonomic levels, using C<--counts>:

  pf qc -t lane -i 12345_1 -s -C

You can also report the number of reads that are assigned directly to each
taxon (C<--directly>):

  pf qc -t lane -i 12345_1 -s -d

You can show a particular taxonomic level, using C<--level>:

  pf qc -t lane -i 12345_1 -s -l C

The default is to output everything at the strain level (C<T>).

Finally, you can transpose the summary report, putting information for a given
lane along the rows of the report, rather than down a column.

  pf qc -t lane -i 12345_1 -s -T

=cut

#-------------------------------------------------------------------------------
#- command line options --------------------------------------------------------
#-------------------------------------------------------------------------------

# this option can be used as a simple switch ("-o") or with an argument
# ("-o mydir"). It's a bit fiddly to set that up...

option 'summary' => (
  documentation => 'write summary info to a CSV file',
  is            => 'ro',
  cmd_aliases   => 's',
  trigger       => \&_check_for_summary_value,
  # no "isa" because we want to accept both Bool and Str and it doesn't seem to
  # be possible to specify that using the combination of MooseX::App and
  # Type::Tiny that we're using here
);

# set up a trigger that checks for the value of the "summary" command-line
# argument and tries to decide if it's a boolean, in which case we'll generate
# a filename, or a string, in which case we'll treat that string as a filename.
sub _check_for_summary_value {
  my ( $self, $new, $old ) = @_;

  if ( not defined $new ) {
    # write info to file specified by the user
    $self->_summary_flag(1);
  }
  elsif ( not is_Bool($new) ) {
    # write info to file specified by the user
    $self->_summary_flag(1);
    $self->_summary( file $new );
  }
  else {
    # don't write file. Shouldn't ever get here
    $self->_summary_flag(0);
  }
}

# private attributes to store the (optional) value of the "summary" attribute.
# When using all of this we can check for "_summary_flag" being true or false,
# and, if it's true, check "_summary" for a value
has '_summary'      => ( is => 'rw', isa => PathClassFile, default => sub { file 'qc_summary.csv' } );
has '_summary_flag' => ( is => 'rw', isa => Bool );

#---------------------------------------

option 'directly' => (
  documentation => 'report reads assigned directly to this taxon',
  is            => 'ro',
  isa           => Bool,
  cmd_aliases   => 'd',
);

#---------------------------------------

option 'level' => (
  documentation => 'output specified taxonomic level',
  is            => 'ro',
  isa           => TaxLevel->plus_coercions(LevelCodeFromName),
  coerce        => 1,
  default       => 'T',
  cmd_aliases   => 'L',
);

#---------------------------------------

option 'counts' => (
  documentation => 'use counts in summary instead of percentages',
  is            => 'ro',
  isa           => Bool,
  cmd_aliases   => 'C',
);

#---------------------------------------

option 'transpose' => (
  documentation => 'transpose rows and columns in summary',
  is            => 'ro',
  isa           => Bool,
  cmd_aliases   => 'T',
);

#---------------------------------------

# omitting this option as an unused option from the old qcfind

# option 'min_cutoff' => (
#   documentation => '',
#   is            => 'ro',
#   isa           => Num,
#   cmd_aliases   => 'm',
# );

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# this is a builder for the "_lane_class" attribute, which is defined on the
# parent class, B::P::F::A::PathFind. The return value specifies the class of
# object that should be returned by the B::P::F::Finder::find_lanes method.

sub _build_lane_class {
  return 'Bio::Path::Find::Lane::Class::QC';
}

#---------------------------------------

sub _build_tar_filename {
  my $self = shift;
  return file( 'qc_' . $self->_renamed_id . ( $self->no_tar_compression ? '.tar' : '.tar.gz' ) );
}

#---------------------------------------

sub _build_zip_filename {
  my $self = shift;
  return file( 'qc_' . $self->_renamed_id . '.zip' );
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

  if ( $self->_tar_flag  and -f $self->_tar and not $self->force ) {
    Bio::Path::Find::Exception->throw(
      msg => q(ERROR: tar archive ") . $self->_tar . q(" already exists; not overwriting existing file)
    );
  }

  if( $self->_zip_flag and -f $self->_zip and not $self->force ) {
    Bio::Path::Find::Exception->throw(
      msg => q(ERROR: zip file ") . $self->_zip . q(" already exists; not overwriting existing file)
    );
  }

  if ( $self->_summary_flag and -f $self->_summary and not $self->force ) {
    Bio::Path::Find::Exception->throw(
      msg => q(ERROR: CSV file ") . $self->_summary . q(" already exists; not overwriting existing file)
    );
  }

  #---------------------------------------

  my %finder_params = (
    ids      => $self->_ids,
    type     => $self->type,
    filetype => 'kraken',
  );

  # should we look for lanes with the "qc" bit set on the "processed" bit field
  # ? Turning this off, i.e. setting the command line option
  # "--ignore-processed-flag" will allow the command to return data for lanes
  # that haven't completed the qc pipeline.
  $finder_params{processed} = Bio::Path::Find::Types::QC_PIPELINE
    unless $self->ignore_processed_flag;

  # actually go and find lanes
  my $lanes = $self->_finder->find_lanes(%finder_params);

  $self->log->debug( 'found a total of ' . scalar @$lanes . ' lanes' );

  unless ( @$lanes ) {
    say STDERR 'No data found.';
    exit;
  }

  # what are we doing with the lanes that we found ?
  if ( $self->_tar_flag or
       $self->_zip_flag or
       $self->_symlink_flag or
       $self->_summary_flag ) {
    $self->_make_tar($lanes) if $self->_tar_flag;
    $self->_make_zip($lanes) if $self->_zip_flag;
    $self->_make_links($lanes) if $self->_symlink_flag;
    $self->_make_summary($lanes) if $self->_summary_flag;
  }
  else {
    $_->print_paths for ( @$lanes );
  }
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# override the default method from Bio::Path::Find::App::Role::Archivist. This
# one doesn't bother creating a stats file, which the origin method does, by
# calling the "stats" and "stats_headers" methods on the lanes

sub _collect_filenames {
  my ( $self, $lanes ) = @_;

  my @kraken_report_files;

  foreach my $lane ( @$lanes ) {
    foreach my $file ( $lane->all_files ) {
      push @kraken_report_files, { $file => $file };
    }
  }

  # my @kraken_report_files = map { $_->all_files } @$lanes;

  return \@kraken_report_files;
}

#-------------------------------------------------------------------------------

# writes out a CSV file containing the summary of the kraken reports for the
# specified lanes

sub _make_summary {
  my ( $self, $lanes ) = @_;

  print STDERR 'generating summary... ';

  my $summary = $self->_summary->stringify;

  # collect a list of the filenames for the kraken reports
  my @kraken_report_files = map { $_->all_files } @$lanes;

  # "all_files" returns a list of Path::Class::File objects, but we can't hand
  # those straight to KrakenSummary because it will complain that they're not
  # strings, hence...
  my @report_filenames = map { $_->stringify } @kraken_report_files;

  my $kraken_summary = Bio::Metagenomics::External::KrakenSummary->new(
    report_files      => \@report_filenames,
    outfile           => $summary,
    taxon_level       => $self->level,
    counts            => $self->counts,
    assigned_directly => $self->directly,
    transpose         => $self->transpose,
  );

  $kraken_summary->run;

  print STDERR "\rreading summary... ";

  open my $fh, '<:encoding(utf8)', $summary
    or Bio::Path::Find::Exception( msg => q(ERROR: couldn't open summary TSV file for read) );

  $self->_csv->sep("\t"); # we know that the KrakenSummary module writes TSV

  my $data = $self->_csv->getline_all($fh);

  # the summary uses the filenames of the kraken reports as the labels for
  # the data. If "transpose" is set, the labels are in the first column,
  # otherwise the labels are in the first row, the header of the CSV. Either
  # way, we need to edit the labels to convert them from filenames into lane
  # names. We can do that by getting the parent directory for the report
  # file, which, handily, is the lane name.

  if ( $self->transpose ) {
    # take a slice of the data array, skipping the first row, which contains
    # the column names
    foreach my $row ( @$data[1 .. @$data ] ) {
      # convert the first column from a file path to a directory name, where
      # the directory gives us the name of the lane
      my $lane_name = file($row->[0])->parent->basename;
      $row->[0] = $lane_name;
    }
  }
  else {
    # get the labels from the first row of the data array
    my @column_names = map { file($_)->parent->basename } @{ $data->[0] };

    # put back the first column header, which gets lost when we convert the
    # column names to Path::Class::File objects
    $column_names[0] = 'Species';

    # and overwrite the column names row in the data array
    $data->[0] = \@column_names;
  }

  close $fh;

  # make sure we reset the CSV separator with whatever separator the user
  # actually specified, or, at least, with our own default
  $self->_csv->sep( $self->csv_separator );

  print STDERR "\rwriting summary... ";

  # write the edited CSV
  open $fh, '>:encoding(utf8)', $summary
    or Bio::Path::Find::Exception( msg => q(ERROR: couldn't open summary CSV file for write) );

  $self->_csv->print($fh, $_) for @$data;

  close $fh;

  say STDERR qq(done\rwrote summary as '$summary');
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

