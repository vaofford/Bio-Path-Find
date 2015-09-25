
package Bio::Path::Find::Types;

use Type::Library -base, -declare => qw(
  BioTrackSchema
  BioPathFindDatabaseManager
  BioPathFindDatabase
  BioPathFindFilter
  BioPathFindSorter
  IDType
  Environment
);

use Type::Utils -all;
use Types::Standard -types;

class_type 'Bio::Track::Schema';
class_type 'Bio::Path::Find::DatabaseManager';
class_type 'Bio::Path::Find::Database';
class_type 'Bio::Path::Find::Filter';
class_type 'Bio::Path::Find::Sorter';

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

