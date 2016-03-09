
package Bio::Path::Find::Types;

# ABSTRACT: a type library for path find

use Config::Any;
use Bio::Path::Find::Exception;

=head1 CONTACT

path-help@sanger.ac.uk

=head1 SYNOPSIS

  package MyApp;

  use Moose;

  use Bio::Path::Find::Types qw(
    PathClassFile
    Assembler
  );

  has 'some_file' => (
    is  => 'ro',
    isa => PathClassFile,
  );

  has 'my_assembler' => (
    is  => 'ro',
    isa => Assembler,
  );

  sub do_something {
    my $self = shift;

    my @contents = $self->some_file->slurp;
    ...
  }

=head1 DESCRIPTION

This is a L<Type::Tiny>-based type library for the path find module.

=head1 SEE ALSO

L<Type::Tiny::Manual>
L<Type::Library>

=cut

#-------------------------------------------------------------------------------

use Path::Class;
use Bio::Path::Find::ConfigSingleton;

use Type::Library -base, -declare => qw(
  PathClassFile
  PathClassDir
  AnnotationType
  AssemblyType
  DataType
  RefType
  Assembler
  ProcessedFlag
  QCType
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
class_type 'Bio::Path::Find::RefFinder';
class_type 'Bio::Path::Find::Lane';
class_type 'Bio::Path::Find::Sorter';
class_type 'Bio::Path::Find::Lane::Status';
class_type 'Bio::Path::Find::Lane::StatusFile';
class_type 'Path::Class::Entity';
class_type 'Path::Class::File';
class_type 'Path::Class::Dir';
class_type 'URI::URL';

#---------------------------------------

# set up constants that map pipeline names to bit flags
use constant {
  IMPORT_PIPELINE             => 1,
  QC_PIPELINE                 => 2,
  MAPPED_PIPELINE             => 4,
  STORED_PIPELINE             => 8,
  DELETED_PIPELINE            => 16,
  SWAPPED_PIPELINE            => 32,
  ALTERED_FASTQ_PIPELINE      => 64,
  IMPROVED_PIPELINE           => 128,
  SNP_CALLED_PIPELINE         => 256,
  RNA_SEQ_EXPRESSION_PIPELINE => 512,
  ASSEMBLED_PIPELINE          => 1024,
  ANNOTATED_PIPELINE          => 2048,
};

# and map the "friendly" pipeline names used in configs, etc.
# to those same bit flags
our $pipeline_names = {
# pipeline name         binary value
  import             => IMPORT_PIPELINE,
  qc                 => QC_PIPELINE,
  mapped             => MAPPED_PIPELINE,
  stored             => STORED_PIPELINE,
  deleted            => DELETED_PIPELINE,
  swapped            => SWAPPED_PIPELINE,
  altered_fastq      => ALTERED_FASTQ_PIPELINE,
  improved           => IMPROVED_PIPELINE,
  snp_called         => SNP_CALLED_PIPELINE,
  rna_seq_expression => RNA_SEQ_EXPRESSION_PIPELINE,
  assembled          => ASSEMBLED_PIPELINE,
  annotated          => ANNOTATED_PIPELINE,
};

# invert the hash so that we can quickly check that a given
# int is a valid flag
our $pipeline_flags = { reverse %$pipeline_names };

# declare a type for a processed flag
declare ProcessedFlag,
  as Int,
  where { exists $pipeline_flags->{$_} };

# (not convinced we need this)
declare_coercion 'PipelineFlagFromStr',
  to_type ProcessedFlag,
  from    Int,
  q{ $pipeline_names->{$_} };

#---------------------------------------

declare_coercion 'FileFromStr',
  to_type PathClassFile,
  from    Str, q{ Path::Class::file $_ };

declare_coercion 'DirFromStr',
  to_type PathClassDir,
  from    Str, q{ Path::Class::dir $_ };

declare_coercion 'URLFromStr',
  to_type URIURL,
  from    Str, q{ URI::URL->new($_) };

enum IDType,         [qw( lane sample database study file library species )];
enum FileIDType,     [qw( lane sample study )];
enum QCState,        [qw( passed failed pending )];
enum Assembler,      [qw( velvet spades iva pacbio )];
enum DataType,       [qw( fastq bam pacbio corrected )];
enum AssemblyType,   [qw( scaffold contigs all )];
enum AnnotationType, [qw( gff faa ffn gbk fasta fastn genbank )];
enum RefType,        [qw( fa gff embl )];
enum QCType,         [qw( kraken )];

declare FileType,
  as AnnotationType|AssemblyType|DataType|RefType|QCType;

#---------------------------------------

# these are labels for the taxonomic levels accepted by the QC command
enum TaxLevel, [qw( D P C O F G S T )];

#---------------------------------------

# (see https://metacpan.org/pod/release/TOBYINK/Type-Tiny-1.000005/lib/Type/Tiny/Manual/Libraries.pod)
class_type 'Datetime', { class => 'DateTime' };

coerce Datetime,
  from Int,   via { 'DateTime'->from_epoch( epoch => $_ ) },
  from Undef, via { 'DateTime'->now };

#---------------------------------------

class_type 'Bio::Path::Find::ConfigSingleton';

declare_coercion 'ConfigFromHash',
  to_type BioPathFindConfigSingleton,
  from    HashRef, via { Bio::Path::Find::ConfigSingleton->initialize(config_hash => $_) };

declare_coercion 'ConfigFromStr',
  to_type BioPathFindConfigSingleton,
  from    Str, via {
    return _singleton_from_file(file $_);
  };

declare_coercion 'ConfigFromFile',
  to_type BioPathFindConfigSingleton,
  from    PathClassFile, via {
    return _singleton_from_file($_);
  };

sub _singleton_from_file {
  my $file = shift;

  Bio::Path::Find::Exception->throw(msg => "ERROR: can't find config file ($file)")
    if not -f $file;

  my $ca = Config::Any->load_files( { files => [$file], use_ext => 1 } );
  my $cfg = $ca->[0]->{$file};

  Bio::Path::Find::Exception->throw(msg => "ERROR: failed to read config file ($file)")
    if not defined $cfg;

  return Bio::Path::Find::ConfigSingleton->initialize(config_hash => $cfg);
}

#---------------------------------------

declare Assemblers,
  as ArrayRef[Assembler];

declare_coercion 'AssemblersFromAssembler',
  to_type Assemblers,
  from    Assembler,  via { [ $_ ] };

#-------------------------------------------------------------------------------

1;

