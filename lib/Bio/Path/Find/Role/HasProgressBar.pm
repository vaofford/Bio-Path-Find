
package Bio::Path::Find::Role::HasProgressBar;

# ABSTRACT: role providing methods for adding progress bars

use Moose::Role;

use Term::ProgressBar::Simple;

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

# build a progress bar. If there is a config method on the object and
# "no_progress_bar" is set to true in the config, we don't create a progress
# bar but return zero, so that the caller can still increment the progress bar
# without any ill effects. If we do create a progress bar, "remove" is always
# set to true.

sub _create_pb {
  my ( $self, $name, $max ) = @_;

  my $pb = ( $self->can('config') and $self->config->{no_progress_bars} )
         ? 0
         : Term::ProgressBar::Simple->new( {
             name   => $name,
             count  => $max,
             remove => 1,
           } );

  return $pb;
}

#-------------------------------------------------------------------------------

1;
