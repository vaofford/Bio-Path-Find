
package Bio::Path::Find::Types;

use Type::Library -base, -declare => qw(
  BioTrackSchema
  BioTrackSchemaResultBase
  BioTrackSchemaResultLatestLane
  BioPathFindDatabaseManager
  BioPathFindDatabase
  BioPathFindLane
  BioPathFindSorter
  PathClassFile
  PathClassDir
  IDType
  FileIDType
  QCState
  FileType
  Environment
);

use Type::Utils -all;
use Types::Standard -types;

class_type 'Bio::Track::Schema';
class_type 'Bio::Track::Schema::ResultBase';
class_type 'Bio::Track::Schema::Result::LatestLane';
class_type 'Bio::Path::Find::DatabaseManager';
class_type 'Bio::Path::Find::Database';
class_type 'Bio::Path::Find::Lane';
class_type 'Bio::Path::Find::Sorter';
class_type 'Path::Class::File';
class_type 'Path::Class::Dir';

enum IDType,      [qw( lane sample database study file library species )];
enum FileIDType,  [qw( lane sample study)];
enum QCState,     [qw( passed failed pending )];
enum FileType,    [qw( fastq bam pacbio corrected )];
enum Environment, [qw( test prod )];

1;

