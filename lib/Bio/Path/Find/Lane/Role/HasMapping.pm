
package Bio::Path::Find::Lane::Role::HasMapping;

# ABSTRACT: a role that provides functionality related to mapped reads

use Moose::Role;

use Path::Class;

use Types::Standard qw(
  Str
);

use Bio::Path::Find::Types qw( :all );

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

=attr mappers

A list of names of mappers that the mapping-related code understands. The
default list is taken from the definition of the C<Mapper> type in the
L<type library|Bio::Path::Find::Types>.

=cut

has 'mappers' => (
  is      => 'rw',
  isa     => Mappers->plus_coercions(MappersFromMapper),
  coerce  => 1,
  lazy    => 1,
  builder => '_build_mappers',
);

sub _build_mappers {
  return Mapper->values;
}

# TODO validate user-supplied values against the list of available mappers

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

has '_available_mappers' => (
  is => 'ro',
  isa => Str,
  # TODO add sensible defaults here but allow this list to be overridden by the
  # config
);

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------

1;

