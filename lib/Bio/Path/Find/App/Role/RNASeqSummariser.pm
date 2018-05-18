
package Bio::Path::Find::App::Role::RNASeqSummariser;

# ABSTRACT: role providing methods for archiving data

use v5.10; # for "say"

use MooseX::App::Role;

=head1 CONTACT
a
path-help@sanger.ac.uk

=cut

use Path::Class;

use Bio::Path::Find::Exception;

use Types::Standard qw(
  +Bool
);

use Bio::Path::Find::Types qw(
  PathClassFile
);

with 'Bio::Path::Find::Role::HasProgressBar';


#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

option 'summary' => (
  documentation => 'filename for summary TSV output',
  is            => 'rw',
  # no "isa" because we want to accept both Bool and Str
  cmd_aliases   => 'S',
  trigger       => \&_check_for_summary_value,
);

sub _check_for_summary_value {
  my ( $self, $new, $old ) = @_;

  if ( not defined $new ) {
    $self->_summary_flag(1);
  }
  elsif ( not is_Bool($new) ) {
    $self->_summary_flag(1);
    $self->_summary_file( file $new );
  }
  else {
    $self->_summary_flag(0);
  }
}

has '_summary_flag' => ( is => 'rw', isa => Bool );

has '_summary_file' => (
  is      => 'rw',
  isa     => PathClassFile,
  lazy    => 1,
  builder => '_build_summary_file',
);

sub _build_summary_file {
  my $self = shift;
  return file( $self->_renamed_id . '.rnaseqfind_summary.tsv' );
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# build a CSV file with the statistics for all lanes and write it to file

sub _make_summary {
  my ( $self, $lanes ) = @_;

  #collect the info for the supplied lanes
  my @summary = (
    $lanes->[0]->summary_headers,
  );

  my $pb = $self->_create_pb('collecting summary', scalar @$lanes);

  foreach my $lane ( @$lanes ) {
    push @summary, $lane->summary;
    $pb++;
  }

  $self->_csv->sep("\t");
  $self->_write_csv(\@summary, $self->_summary_file);

  say q(Wrote summary to ") . $self->_summary_file . q(");
}

#-------------------------------------------------------------------------------

1;