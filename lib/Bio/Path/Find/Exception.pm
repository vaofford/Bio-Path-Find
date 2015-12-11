
package Bio::Path::Find::Exception;

# ABSTRACT: a simple exception class for the Bio::Path::Find namespace

use Moose;
use MooseX::StrictConstructor;

# using namespace::autoclean here breaks the stringification, and therefore the
# behaviour of this class with Test::Exception::throws_ok, etc.
# use namespace::autoclean;

use overload q("") => sub { shift->as_string };

use Types::Standard qw( Str );

with 'Throwable';

has 'msg' => (
  is  => 'ro',
  isa => Str,
);

sub as_string {
  my $self = shift;
  return $self->msg;
}

__PACKAGE__->meta->make_immutable;

1;

