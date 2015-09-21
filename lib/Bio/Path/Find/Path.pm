
package Bio::Path::Find::Path;

# ABSTRACT: class to handle interactions with a pathogens data directory

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Types::Standard qw( Str HashRef );
use Carp qw( croak carp );

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

=cut

has 'db_root' => (
  is       => 'rw',
  isa      => Str,
);

has 'database' => (
  is       => 'rw',
  isa      => BioPathFindDatabase
);

has 'hierarchy_template' => (
  is      => 'ro',
  isa     => Str,
  default => 'genus:species-subspecies:TRACKING:projectssid:sample:technology:library:lane',
);

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

