
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

=head1 USAGE

pf accession --id <id> --type <ID type> [options]

=head1 DESCRIPTION

Given a study ID, lane ID, or sample ID, or a file containing a list of IDs,
this script will return the accessions associated with the specified lane(s).

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
# a directory name to hold links, or a string, in which case we'll treat that
# string as a directory name.
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
    $self->_write_list(\@urls, $self->_fastq) if scalar @urls;

    say STDERR q(Wrote ENA URLs for fastq files to ") . $self->_fastq . q(");
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
    $self->_write_list(\@urls, $self->_submitted) if scalar @urls;

    say STDERR q(Wrote ENA URLs for submitted files to ") . $self->_submitted . q(");
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

