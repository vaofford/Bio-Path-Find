
package Bio::Path::Find::RefFinder;

# ABSTRACT: find reference genomes

use v5.10; # required for Type::Params use of "state"

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw( carp );
use Path::Class;
use String::Approx qw( amatch );

use Type::Params qw( compile );
use Types::Standard qw(
  Object
  HashRef
  ArrayRef
  Str
  Optional
  Maybe
);

use Bio::Path::Find::Types qw(
  PathClassFile
  FileFromStr
  RefType
);

use Bio::Path::Find::Exception;

with 'MooseX::Log::Log4perl',
     'Bio::Path::Find::Role::HasConfig',
     'Bio::Path::Find::Role::HasProgressBar';

=head1 CONTACT

path-help@sanger.ac.uk

=cut

=head1 SYNOPSIS

  # create a RefFinder
  my $rf = Bio::Path::Find::RefFinder->new( config => 'prod.conf' );

  # get matching reference genome names
  my $names = $rf->find_refs(['acinetobacter']);

  # look up paths for the returned genomes
  my $paths = $rf->lookup_paths($names);

  # same thing but in a single step
  $paths = $rf->find_paths('baumanii');

=head1 DESCRIPTION

The C<Bio::Path::Find::RefFinder> class contains methods for finding
reference genomes in the index of available genomes and for returning the
paths for various types of files that are associated with the reference
genoems

A configuration hash or file location must be specified when instantiating,
unless the configuration is already loaded and available as a
L<Bio::Path::Find::ConfigSingleton> (see L<Bio::Path::Find::Role::HasConfig>).
The configuration must specify two parameters: B<refs_index>, giving the file
location for the index of reference genomes; and B<refs_root>, giving the
path to the root of the directory tree containing the reference genomes.

The index should be a simple text file, in which each line contains two
values, separated by a tab character. The first column must give the name of
a reference genome, while the second gives the location of the fasta file
containing the genome sequence.

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

Inherits C<config> from L<Bio::Path::Find::Role::HasConfig>.

=attr index_file

The location of the reference index file (usually called C<refs.index>). Can be
given either a string or a L<Path::Class::File> object. If no value is
specified, we try to read the configuration and look for the key C<refs_index>.
If that key is not set in the configuration, or if it doesn't point to a valid
file on disk, an exception is thrown.

=cut

has 'index_file' => (
  is      => 'ro',
  isa     => PathClassFile->plus_coercions(FileFromStr),
  lazy    => 1,
  builder => '_build_index_file',
);

sub _build_index_file {
  my $self = shift;

  unless ( defined $self->config->{refs_index} ) {
    Bio::Path::Find::Exception->throw(
      msg => q(ERROR: location of reference genomes index (usually "refs_index") is not defined in config),
    );
  }

  my $refs_index = file $self->config->{refs_index};

  unless ( -f $refs_index ) {
    Bio::Path::Find::Exception->throw(
      msg => qq|ERROR: can't find reference genome index file ("refs.index") at location given in config ($refs_index)|,
    );
  }

  return $refs_index;
}

#---------------------------------------

=attr index

A reference to a hash containing the index, as read from the C<refs.index> file.
The keys of the hash are the names of the reference genomes, the values are the
paths to the fasta file containing the genome sequence. B<Read-only>; specify
the location of the index file instead.

=cut

has 'index' => (
  is      => 'ro',
  isa     => HashRef,
  lazy    => 1,
  builder => '_build_index',
  writer  => '_set_index',
);

sub _build_index {
  my $self = shift;

  # read in the refs.index file, splitting each line on tab characters
  my @refs = $self->index_file->slurp( chomp => 1, split => qr/\t/ );

  # and convert it to a hash, with the reference genome name as the key and
  # the path to the fasta file for the genome as the value
  my %refs = map { $_->[0] => $_->[1] } @refs;

  # make sure we have at least one mapping in the index that we've just read
  unless ( scalar @refs and
           defined $refs[0]->[0] and defined $refs[0]->[1] ) {
    Bio::Path::Find::Exception->throw(
      msg => q(ERROR: failed to read anything from "refs.index"),
    );
  }

  return \%refs;
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 find_refs($ref_name)

Given the name of a reference genome, this method tries to find the specified
reference genome in the index. Returns a reference to an array, sorted
alphanumerically, containing a list of genome names that match the input
string.

If the supplied name matches exactly, the output array will contain exactly one
entry, the supplied reference name.

If the supplied name does not exactly match a reference genome name, we try a
regular expression match, performing a case-insensitive search of all of the
reference genome names in the index. Again, if there is an exact match to one
genome name, the output array will contain exactly one entry, the name of that
matching genome.

If the search name matches several genome names using the regular expression
match (e.g. "vibrio" will match "Vibrio cholerae" and "Aliivibrio
salmonicida"), the output array will contain a list of all matching reference
genome names.

Finally, if there were no matches using a regular expression search, we fall
back on a fuzzy text search. This allows for minor spelling mistakes and
mis-matches between the supplied name and the reference genome names in the
index. For example, a search for "baumanii" (missing an "n") wil return
I<Acinetobacter baumannii> genomes.

=cut

sub find_refs {
  state $check = compile( Object, Str );
  my ( $self, $search_string ) = $check->(@_);

  $self->log->debug( qq(searching for references using search string "$search_string") );

  # a list of reference names that match the search name
  my $matches = [];

  # catch exact matches immediately
  if ( exists $self->index->{$search_string} ) {
    $self->log->debug('found exact match');
    push @$matches, $search_string;
  }
  else {

    # no exact match, so try a pattern match against the index
    my @possible_matches = grep m/$search_string/i, sort keys %{ $self->index };

    if ( scalar @possible_matches >= 1 ) {
      $self->log->debug('one or more matches found using regex');
      push @$matches, @possible_matches;
    }
    else {
      # we found no matches using the regex; fall back on a fuzzy search
      $self->log->debug('no regex matches; using fuzzy search');

      foreach my $ref ( sort keys %{ $self->index } ) {
        push @$matches, $ref if amatch( $search_string, [ 'i 15%' ], $ref );
      }

      $self->log->debug('found ' . scalar @$matches . ' fuzzy matches');
    }
  }

  return $matches;
}

#-------------------------------------------------------------------------------

=head2 lookup_paths($names_arrayref, $?file_type)

For a given list of reference genome names, return a list of paths to the
specified genomes. Returns a reference to an array containing a list of paths,
in the same order as the input array. The paths are represented as
L<Path::Class::File> objects.

If the optional filetype is specified, the returned array will contain paths to
the files with the specified type. If a reference genome doesn't have a file of
the specified type, the corresponding slot in the output list will be
undefined.

If no filetype is specified, the returned paths point to the directories
containing the reference genomes.

Filetype must be one of C<fa>, C<gff>, or C<embl>. B<Note> that the GFF file is
taken from the C<annotation> sub-directory of the reference genome directory.

=cut

sub lookup_paths {
  state $check = compile( Object, ArrayRef[Str], Optional[Maybe[RefType]] );
  my ( $self, $names, $filetype ) = $check->(@_);

  # for each of the inputs to the method, which should be names of reference
  # genomes in the index, look up the path to the FA file for the genome
  my @fa_paths = map { file( $self->index->{$_} ) } @$names;

  my @files;
  if ( defined $filetype ) {
    # we have a filetype; get the path to the "fa" file for the reference
    # and return the path to the specified file type
    foreach my $fa ( @fa_paths ) {
      my $file;
      if ( $filetype eq 'fa' ) {
        $file = $fa;
      }
      elsif ( $filetype eq 'gff' ) {
        ( my $stub = $fa->basename ) =~ s/\.fa$//;
        $file = file( $fa->parent, 'annotation', "$stub.gff" );
      }
      elsif ( $filetype eq 'embl' ) {
        ( my $embl = $fa ) =~ s/\.fa$/.embl/;
        $file = file $embl;
      }
      # NOTE if we want to return directories from this method, this
      # is the place to do it... Something like:
      #   else {
      #     $file = $fa->parent;
      #   }

      push @files, $file if ( defined $file and -f $file );
    }
  }
  else {
    # if there's no filetype specified, get the path to the "fa" file and
    # return the parent directory for that file
    push @files, map { file( $self->index->{$_} )->parent } @$names;
  }

  return \@files;
}

#-------------------------------------------------------------------------------

=head2 find_paths($search_string, $?file_type)

Given a search string, find paths for matching reference genomes. Internally
this method calls L<find_ref> and hands the list of returned names straight
to L<lookup_paths>, along with C<$file_type>, if specified.

=cut

sub find_paths {
  state $check = compile( Object, Str, Optional[RefType] );
  my ( $self, $search_string, $filetype ) = $check->(@_);

  # look up reference genomes names using the supplied search string
  my $matches = $self->find_refs($search_string);

  # and return paths for those genomes
  return $self->lookup_paths($matches, $filetype);
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

