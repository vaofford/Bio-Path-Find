
package Bio::Path::Find::Role::Statistician;

# ABSTRACT: role providing methods for archiving data

use v5.10; # for "say"

use MooseX::App::Role;

=head1 CONTACT

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

option 'stats' => (
  documentation => 'filename for statistics CSV output',
  is            => 'rw',
  # no "isa" because we want to accept both Bool and Str
  cmd_aliases   => 's',
  trigger       => \&_check_for_stats_value,
);

sub _check_for_stats_value {
  my ( $self, $new, $old ) = @_;

  if ( not defined $new ) {
    $self->_stats_flag(1);
  }
  elsif ( not is_Bool($new) ) {
    $self->_stats_flag(1);
    $self->_stats_file( file $new );
  }
  else {
    $self->_stats_flag(0);
  }
}

has '_stats_flag' => ( is => 'rw', isa => Bool );
# has '_stats_file' => ( is => 'rw', isa => PathClassFile );

has '_stats_file' => (
  is      => 'rw',
  isa     => PathClassFile,
  lazy    => 1,
  builder => '_stats_file_builder',
);

sub _stats_file_builder {
  my $self = shift;
  return file( $self->_renamed_id . '.pathfind_stats.csv' );
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# build a CSV file with the statistics for all lanes and write it to file

sub _make_stats {
  my ( $self, $lanes ) = @_;

  # collect the stats for the supplied lanes
  my @stats = (
    $lanes->[0]->stats_headers,
  );

  my $pb = $self->_create_pb('collecting stats', scalar @$lanes);

  foreach my $lane ( @$lanes ) {
    $lane->filetype($self->filetype);
    push @stats, @{ $lane->stats };
    $pb++;
  }

  $self->_write_csv(\@stats, $self->_stats_file);
}

#-------------------------------------------------------------------------------

1;
