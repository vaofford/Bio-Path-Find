
package Bio::Path::Find::ProgressBar;

# ABSTRACT: a progress bar class using Term::ProgressBar

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Term::ProgressBar;

use Types::Standard qw(
  Str
  Bool
  Num
);

use Bio::Path::Find::Types qw(
  TermProgressBar
);

=head1 SYNOPSIS

  my $pb = Bio::Path::Find::ProgressBar(
    name   => 'searching',
    count  => 100,
    remove => 1,
    ETA    => 1,
    silent => 0,
  );

  my @results;
  for ( my $i = 0; $i < 100; $i++ ) {
    push @results, $i * $i;
    $pb->update($i);
  }

  $pb->finished;

=head1 DESCRIPTION

This class is a thin wrapper around L<Term::ProgressBar>, purely for the
purpose of reducing the amount of boiler plate that's needed to use that class.
It wraps the main parameters that are used to configure the progress bar,
turning them into Moose attributes on this class.

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=head ATTRIBUTES

=attr name

String providing the name label for the progress bar. B<Required>.

=cut

has 'name' => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

=attr count

Item count for the progress bar. B<Required>.

=cut

has 'count' => (
  is       => 'ro',
  isa      => Num,
  required => 1,
  reader   => 'max', # rename "count"; it's more meaningfully called "max"
);

=attr remove

Boolean specifying whether the progress bar should be removed from the terminal
when complete.

Default: true.

=cut

has 'remove' => (
  is      => 'ro',
  isa     => Bool,
  default => 1,
);

=attr

Boolean specifying whether the progress bar should show an ETA for completion.
The usage of this flag differs from its usage in the underlying
L<Term::ProgressBar>, in that here we only need a boolean, rather than C<undef>
or C<linear>. If C<ETA> is set to true, we specify C<linear> to the underlying
progress bar object.

Default: true.

=cut

has 'ETA' => (
  is      => 'ro',
  isa     => Bool,
  default => 1,
);

=attr silent

If true, the progress bar is effectively disabled. Nothing will be printed to
the terminal. Because of the way the L<Term::ProgressBar> is wrapped, there's
no need to treat updating or completion differently, as would be the case if
accessing the progress bar object directly; when C<silent> is set true, calls
to L<Term::ProgressBar::update|update> don't return anything. That wrinkle is
smoothed out here...

Default: false.

=cut

has 'silent' => (
  is      => 'ro',
  isa     => Bool,
  default => 0,
);

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

has '_pb' => (
  is      => 'ro',
  isa     => TermProgressBar,
  lazy    => 1,
  builder => '_build_pb',
);

sub _build_pb {
  my $self = shift;

  my $pb = Term::ProgressBar->new( {
    name   => $self->name,
    count  => $self->max,
    remove => $self->remove,
    ETA    => $self->ETA ? 'linear' : undef,
    silent => $self->silent,
  } );

  # ditch the "completion time estimator" character
  $pb->minor(0);

  return $pb;
}

#---------------------------------------

has '_next_update' => (
  is      => 'rw',
  isa     => Num,
  default => 0,
);

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 update($offset)

Updates the progress bar to the specified offset point.

=cut

sub update {
  my ( $self, $offset ) = @_;

  $self->_next_update( $self->_pb->update($offset) )
    if $offset >= $self->_next_update;
}

#-------------------------------------------------------------------------------

=head2 finished

Moves the progress bar to 100% and, if C<remove> is true, removes it from the
terminal.

=cut

sub finished {
  my $self = shift;

  $self->_pb->update($self->max)
    if $self->max >= $self->_next_update;
}

#-------------------------------------------------------------------------------

=head1 SEE ALSO

L<Term::ProgressBar>

=cut

__PACKAGE__->meta->make_immutable;

1;

