
package Bio::Path::Find::Types;

use Type::Library -base, -declare => qw(
  BioTrackSchema
  BioPathFindPath
  BioPathFindDatabase
  BioPathFindFilter
  BioPathFindSorter
  IDType
  Environment
);

use Type::Utils -all;
use Types::Standard -types;

class_type BioTrackSchema,      { class => 'Bio::Track::Schema' };
class_type BioPathFindPath,     { class => 'Bio::Path::Find::Path' };
class_type BioPathFindDatabase, { class => 'Bio::Path::Find::Database' };
class_type BioPathFindFilter    { class => 'Bio::Path::Find::Filter' };
class_type BioPathFindSorter    { class => 'Bio::Path::Find::Sorter' };

enum IDType, [ qw(
  lane
  sample
  database
  study
  file
  library
  species
) ];

enum Environment, [ qw( test prod ) ];

1;

