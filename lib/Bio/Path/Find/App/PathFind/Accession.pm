
package Bio::Path::Find::App::PathFind::Accession;

# ABSTRACT: find accessions

use v5.10; # for "say"

use MooseX::App::Command;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw( croak );
use Path::Class;
use LWP::UserAgent;
use URI::URL;

use Types::Standard qw(
  +Bool
);

use Bio::Path::Find::Types qw(
  PathClassFile FileFromStr
  URIURL        URLFromStr
);

use Bio::Path::Find::Exception;

extends 'Bio::Path::Find::App::PathFind';

#-------------------------------------------------------------------------------
#- usage text ------------------------------------------------------------------
#-------------------------------------------------------------------------------

# this is used when the "pf" app class builds the list of available commands
command_short_description 'Find accessions for sequencing runs';

=head1 NAME

pf accession - Find accessions for sequencing runs

=head1 USAGE

  pf accession --id <id> --type <ID type> [options]

=head1 DESCRIPTION

The C<accession> command finds accessions for samples. Search for data for by
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

# this option can be used as a simple switch ("-o") or with an argument
# ("-o mydir"). It's a bit fiddly to set that up...

option 'outfile' => (
  documentation => 'write accession info to a CSV file',
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
has '_outfile'      => ( is => 'rw', isa => PathClassFile, default => sub { file 'accessionfind.csv' } );
has '_outfile_flag' => ( is => 'rw', isa => Bool );

#---------------------------------------

option 'fastq' => (
  documentation => 'generate URLs for downloading fastq files from ENA',
  is            => 'ro',
  cmd_aliases   => 'f',
  trigger       => \&_check_for_fastq_value,
  # no "isa"
);

sub _check_for_fastq_value {
  my ( $self, $new, $old ) = @_;

  if ( not defined $new ) {
    # write to file specified by the user
    $self->_fastq_flag(1);
  }
  elsif ( not is_Bool($new) ) {
    # write to file specified by the user
    $self->_fastq_flag(1);
    $self->_fastq( file $new );
  }
  else {
    # don't write file. Shouldn't ever get here
    $self->_fastq_flag(0);
  }
}

has '_fastq'      => ( is => 'rw', isa => PathClassFile, default => sub { file 'fastq_urls.txt' } );
has '_fastq_flag' => ( is => 'rw', isa => Bool );

#---------------------------------------

option 'submitted' => (
  documentation => 'generate URLs for downloading submitted files from ENA',
  is            => 'ro',
  cmd_aliases   => 's',
  trigger       => \&_check_for_submitted_value,
  # no "isa"
);

sub _check_for_submitted_value {
  my ( $self, $new, $old ) = @_;

  if ( not defined $new ) {
    # write to file specified by the user
    $self->_submitted_flag(1);
  }
  elsif ( not is_Bool($new) ) {
    # write to file specified by the user
    $self->_submitted_flag(1);
    $self->_submitted( file $new );
  }
  else {
    # don't write file. Shouldn't ever get here
    $self->_submitted_flag(0);
  }
}

has '_submitted'      => ( is => 'rw', isa => PathClassFile, default => sub { file 'submitted_urls.txt' } );
has '_submitted_flag' => ( is => 'rw', isa => Bool );

#---------------------------------------

# TODO in the future we may want to add a switch that makes the script go off
# TODO to ENA to download a file giving details of the assemblies that match
# TODO the found accessions.

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# an LWP::UserAgent, used for querying the ENA RESTful API to get FTP URLs. We
# store it as an attribute so that it can be overridden for testing.

has '_ua' => (
  is      => 'ro',
  isa     => 'LWP::UserAgent',
  lazy    => 1,
  builder => '_build_ua',
);

sub _build_ua {
  my $ua = LWP::UserAgent->new;
  $ua->env_proxy;
  return $ua;
}

#---------------------------------------

# the URL for the ENA RESTful API endpoint. We check to see if the URL is
# given in the config, otherwise we fall back on the default (taken from
# the old "accessionfind" script).

has '_filereport_url' => (
  is      => 'ro',
  isa     => URIURL->plus_coercions(URLFromStr),
  lazy    => 1,
  builder => '_build_filereport_url',
);

sub _build_filereport_url {
  my $self = shift;

  # see if there's a setting in the config
  my $url = defined $self->config->{filereport_url}
          ? $self->config->{filereport_url}
          : 'http://www.ebi.ac.uk/ena/data/warehouse/filereport';

  return URI::URL->new($url);
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 run

Find accessions according to the input parameters.

=cut

sub run {
  my $self = shift;

  Bio::Path::Find::Exception->throw( msg => q(ERROR: output file ") . $self->_outfile
                                     . q(" already exists; not overwriting) )
    if ( $self->_outfile_flag and -e $self->_outfile );

  Bio::Path::Find::Exception->throw( msg => q(ERROR: fastq URL output file ") . $self->_fastq
                                     . q(" already exists; not overwriting) )
    if ( $self->_fastq_flag and -e $self->_fastq );

  Bio::Path::Find::Exception->throw( msg => q(ERROR: submitted URL output file ") . $self->_submitted
                                     . q(" already exists; not overwriting) )
    if ( $self->_submitted_flag and -e $self->_submitted );

  # find lanes
  my $lanes = $self->_finder->find_lanes(
    ids  => $self->_ids,
    type => $self->type,
  );

  $self->log->debug('found ' . scalar @$lanes . ' lanes');

  # store the information for each sample
  my @info = (
    [ 'Sample name', 'Sample accession', 'Lane name', 'Lane accession' ]
  );

  # and store the accession, so that we can build URLs later if needed
  my @accessions;

  my $pb = $self->_build_pb('finding accessions', scalar @$lanes);

  foreach my $lane ( @$lanes ) {

    my $lane_row       = $lane->row;
    my $sample_row     = $lane_row->latest_library->latest_sample;
    my $individual_row = $sample_row->individual;

    push @info, [
      $sample_row->name    || 'not found',
      $individual_row->acc || 'not found',
      $lane_row->name      || 'not found',
      $lane_row->acc       || 'not found',
    ];

    push @accessions, $lane_row->acc if defined $lane_row->acc;
    $pb++;
  }

  # should we send accession information to file ?
  if ( $self->_outfile_flag ) {
    $self->_write_csv( \@info, $self->_outfile );
    say STDERR q(Wrote accessions to ") . $self->_outfile . q(");
  }
  else {
    printf "%-15s %-25s %-25s %-25s\n", @$_ for @info;
  }

  # should we generate and save FTP URLs for fastq files ?
  if ( $self->_fastq_flag ) {
    $self->log->debug('getting URLs from ENA for fastq files');

    $pb = $self->_build_pb('getting fastq URLs', scalar @$lanes);

    my @urls;
    foreach my $accession ( @accessions ) {
      push @urls, $self->_build_url($accession, 'fastq');
      $pb++
    }

    if ( scalar @urls ) {
      $self->_write_list(\@urls, $self->_fastq);
      say STDERR q(Wrote ENA URLs for fastq files to ") . $self->_fastq . q(");
    }
    else {
      say STDERR q(No matching fastq files found in ENA; not writing file of URLs);
    }
  }

  # should we generate and save FTP URLs for submitted files ?
  if ( $self->_submitted_flag ) {
    $self->log->debug('getting URLs from ENA for submitted files');

    $pb = $self->_build_pb('getting submitted data URLs', scalar @$lanes);

    my @urls;
    foreach my $accession ( @accessions ) {
      push @urls, $self->_build_url($accession, 'submitted');
      $pb++
    }

    if ( scalar @urls ) {
      $self->_write_list(\@urls, $self->_submitted);
      say STDERR q(Wrote ENA URLs for submitted files to ") . $self->_submitted . q(");
    }
    else {
      say STDERR q(No submitted files found in ENA; not writing file of URLs);
    }
  }

  # TODO if requested, go off and check ENA for assemblies matching the found
  # TODO accessions.
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# query ENA to get URLs

sub _build_url {
  my ( $self, $accession, $which ) = @_;

  # add query terms to the URI::URL object that's already set up
  $self->_filereport_url->query_form(
    accession => $accession,
    result    => 'read_run',
    fields    => $which eq 'submitted' ? 'submitted_ftp' : 'fastq_ftp',
  );

  my $res = $self->_ua->get($self->_filereport_url);

  croak qq(ERROR: failed to retrieve ENA URLs for accession "$accession": ) . $res->status_line
    unless $res->is_success;

  croak qq(ERROR: couldn't parse ENA response when retrieving ENA URLs for accession "$accession")
    unless $res->decoded_content =~ m/\.ebi\.ac\.uk/;

  # the query result looks something like:
  #
  #  submitted_ftp
  #  ftp.sra.ebi.ac.uk/vol1/ERA123/ERA123456/srf/1234_5#1.srf
  #
  # so we split on newline and use the second row in the map below
  my @content = split m/\n/, $res->decoded_content;

  # if we ask for URLs for fastq files, we could get a semi-colon delimited
  # list of URLs. Split the response string on ";" and tack on "ftp://" to
  # make the result a valid URL
  return map { "ftp://$_" } split m/;/, $content[1];
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

