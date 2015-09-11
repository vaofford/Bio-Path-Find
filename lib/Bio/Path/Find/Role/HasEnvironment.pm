
package Bio::Path::Find::Role::HasEnvironment;

# ABSTRACT: role providing attributes for handling test versus production environments

use Moo::Role;

use Bio::Path::Find::Types qw( Environment );

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

=attr environment

The runtime environment. Must be either C<prod> or C<test>. The default is
C<prod>, unless specified explicitly at instantiation or by setting the
environment variable C<TEST_PATHFIND>. If C<TEST_PATHFIND> is true,
C<environment> defaults to 'C<test>'.

Must be set at instantiation or via C<TEST_PATHFIND> environment variable.

=cut

has 'environment' => (
  is       => 'ro',
  isa      => Environment,
  default  => sub {
    return $ENV{TEST_PATHFIND}
           ? 'test'
           : 'prod';
  },
);

#-------------------------------------------------------------------------------

1;
