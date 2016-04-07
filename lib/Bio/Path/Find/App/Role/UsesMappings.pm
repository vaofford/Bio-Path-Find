
package Bio::Path::Find::App::Role::UsesMappings;

# ABSTRACT: role providing attributes for handling mappings

use v5.10; # for "say"

use MooseX::App::Role;

=head1 CONTACT

path-help@sanger.ac.uk

=cut

use Types::Standard qw(
  Str
  Bool
);

use Bio::Path::Find::Types qw( :types MappersFromMapper );

use Bio::Path::Find::RefFinder;

#-------------------------------------------------------------------------------
#- command line options --------------------------------------------------------
#-------------------------------------------------------------------------------

option 'details' => (
  documentation => 'show details for each mapping run',
  is            => 'ro',
  isa           => Bool,
  cmd_aliases   => 'd',
);

option 'reference' => (
  documentation => 'show only lanes that were mapped against a specific reference',
  is            => 'ro',
  isa           => Str,
  cmd_aliases   => 'R',
);

option 'mapper' => (
  documentation => 'show only lanes with assemblies mapped with specific mapper(s)',
  is            => 'rw',
  isa           => Mappers->plus_coercions(MappersFromMapper),
  coerce        => 1,
  cmd_aliases   => 'M',
  cmd_split     => qr/,/,
);

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# an instance of Bio::Path::Find::RefFinder. Used for converting a reference
# genome name into a path to its sequence file

has '_ref_finder' => (
  is      => 'ro',
  isa     => BioPathFindRefFinder,
  builder => '_build_ref_finder',
  lazy    => 1,
);

sub _build_ref_finder {
  return Bio::Path::Find::RefFinder->new;
}

#-------------------------------------------------------------------------------

1;

