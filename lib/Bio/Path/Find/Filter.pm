
package Bio::Path::Find::Filter;

# ABSTRACT: class to filter sets of results from a path find search

use Moose;
use namespace::autoclean;

with 'Bio::Path::Find::Role::HasEnvironment',
     'Bio::Path::Find::Role::HasConfig';

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

Inherits C<config> and C<environment> from the roles
L<Bio::Path::Find::Role::HasConfig> and
L<Bio::Path::Find::Role::HasEnvironment>.

=cut

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=cut

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

