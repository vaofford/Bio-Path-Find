
package Bio::Path::Find::Types;

# ABSTRACT: a type library for path find

use Try::Tiny;
use Carp qw( croak );

use Type::Library -base, -declare => qw(
  BioTrackSchema
  BioTrackSchemaResultBase
  BioTrackSchemaResultLatestLane
  BioPathFindDatabaseManager
  BioPathFindDatabase
  BioPathFindFinder
  BioPathFindLane
  BioPathFindSorter
  BioPathFindLaneStatus
  BioPathFindLaneStatusFile
  PathClassFile
  PathClassDir
  Datetime
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
class_type 'Bio::Path::Find::Finder';
class_type 'Bio::Path::Find::Lane';
class_type 'Bio::Path::Find::Sorter';
class_type 'Bio::Path::Find::LaneStatus';
class_type 'Bio::Path::Find::LaneStatusFile';
class_type 'Path::Class::File';
class_type 'Path::Class::Dir';

declare_coercion 'FileFromStr',
  to_type PathClassFile,
  from    Str, q{ file $_ };

declare_coercion 'DirFromStr',
  to_type PathClassDir,
  from    Str, q{ dir $_ };

# (see https://metacpan.org/pod/release/TOBYINK/Type-Tiny-1.000005/lib/Type/Tiny/Manual/Libraries.pod)
class_type 'Datetime', { class => 'DateTime' };

coerce Datetime,
  from Int,   via { 'DateTime'->from_epoch( epoch => $_ ) },
  from Undef, via { 'DateTime'->now };

enum IDType,      [qw( lane sample database study file library species )];
enum FileIDType,  [qw( lane sample study)];
enum QCState,     [qw( passed failed pending )];
enum FileType,    [qw( fastq bam pacbio corrected )];
enum Environment, [qw( test prod )];

1;

