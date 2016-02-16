
package Bio::Path::Find::ConfigSingleton;

# ABSTRACT: a singleton class that stores the configuration hash

use MooseX::Singleton;

use Types::Standard qw( HashRef );

=head1 CONTACT

path-help@sanger.ac.uk

=head1 DESCRIPTION

This is a L<MooseX::Singleton> that stores the configuration for an
application. It's intended to be used with the
L<HasConfig|Bio::Path::Find::Role::HasConfig> C<Role> from the path find
package. See that file for details of its use.

=head1 ATTRIBUTES

=attr config_hash

A reference to the hash containing the application configuration.

=head1 SEE ALSO

L<Bio::Path::Find::Role::HasConfig>

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

has 'config_hash' => (
  is      => 'rw',
  isa     => HashRef,
  default => sub { {} },
);

#-------------------------------------------------------------------------------

1;

