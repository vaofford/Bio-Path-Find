
package Bio::Path::Find::Types;

# ABSTRACT: a type library for path find

use Path::Class;

use Type::Library -base, -declare => qw(
  PathClassFile
  PathClassDir
  AnnotationType
  AssemblyType
  DataType
  Assembler
);

use Type::Utils -all;
use Types::Standard -types;

class_type 'DBIx::Class::Schema';
class_type 'Bio::Track::Schema';
class_type 'Bio::Track::Schema::ResultBase';
class_type 'Bio::Track::Schema::Result::LatestLane';
class_type 'Bio::Path::Find::DatabaseManager';
class_type 'Bio::Path::Find::Database';
class_type 'Bio::Path::Find::Finder';
class_type 'Bio::Path::Find::Lane';
class_type 'Bio::Path::Find::Sorter';
class_type 'Bio::Path::Find::Lane::Status';
class_type 'Bio::Path::Find::Lane::StatusFile';
class_type 'Path::Class::File';
class_type 'Path::Class::Dir';
class_type 'URI::URL';

declare_coercion 'FileFromStr',
  to_type PathClassFile,
  from    Str, q{ Path::Class::file $_ };

declare_coercion 'DirFromStr',
  to_type PathClassDir,
  from    Str, q{ Path::Class::dir $_ };

declare_coercion 'URLFromStr',
  to_type URIURL,
  from    Str, q{ URI::URL->new($_) };

# (see https://metacpan.org/pod/release/TOBYINK/Type-Tiny-1.000005/lib/Type/Tiny/Manual/Libraries.pod)
class_type 'Datetime', { class => 'DateTime' };

coerce Datetime,
  from Int,   via { 'DateTime'->from_epoch( epoch => $_ ) },
  from Undef, via { 'DateTime'->now };

enum IDType,         [qw( lane sample database study file library species )];
enum FileIDType,     [qw( lane sample study )];
enum QCState,        [qw( passed failed pending )];
enum Assembler,      [qw( velvet spades iva pacbio )];

declare Assemblers,
  as ArrayRef[Assembler];

declare_coercion 'AssemblerToAssemblers',
  to_type Assemblers,
  from    Assembler,  via { [ $_ ] };

enum DataType,       [qw( fastq bam pacbio corrected )];
enum AssemblyType,   [qw( scaffold contigs all )];
enum AnnotationType, [qw( gff faa ffn gbk fasta fastn genbank )];

declare FileType,
  as AnnotationType|AssemblyType|DataType;

1;

