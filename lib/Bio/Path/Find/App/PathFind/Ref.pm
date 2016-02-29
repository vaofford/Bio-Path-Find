
package Bio::Path::Find::App::PathFind::Ref;

# ABSTRACT: Find reference genones

use v5.10; # for "say"

use MooseX::App::Command;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Term::ANSIColor;

use Types::Standard qw(
  ArrayRef
  Str
  +Bool
);

use Bio::Path::Find::Types qw( :types );

use Bio::Path::Find::RefFinder;

extends 'Bio::Path::Find::App::PathFind';

#-------------------------------------------------------------------------------
#- usage text ------------------------------------------------------------------
#-------------------------------------------------------------------------------

# this is used when the "pf" app class builds the list of available commands
command_short_description 'Find reference genomes';

# the module POD is used when the users runs "pf man ref"

=head1 NAME

pf ref - Find reference genomes

=head1 USAGE

  pf ref --id <genome name>

=head1 DESCRIPTION

This command finds reference genome sequences. Given the name of a reference
genome, the command looks in the index of available references and returns
the path to a single fasta file containing the reference genome sequence.

If an exact match to the genome name is not found, the command returns a
list of any genomes that are an approximate match to the specified name;
choose the exact match from the list and run the command again with the
exact name to return the path for the sequence file.

Use "pf man" or "pf man ref" to see more information.

=head1 EXAMPLES

  # get the path to a sequence file using an exact name
  pf ref -i Yersinia_pestis_CO92_v1

  # find a reference using an approximate name
  pf ref -i yersinia_pestis

  # you can use spaces in names instead of underscores; quote the name
  pf ref -i 'yersinia pestis'

  # find approximate matches for a name
  pf ref -i yersinia

  # also handles minor spelling mistakes
  pf ref -i yersina    # missing an "i"

=head1 OPTIONS

The C<pf ref> command requires only the name of the reference genome.
There are no other options.

=head1 SCENARIOS

=head2 Find a reference genome using an exact name

If you know the exact name of a reference genome, you can get the path to
the sequence file immediately:

  % pf ref -i Yersinia_pestis_CO92_v1
  /scratch/pathogen/refs/Yersinia/pestis_CO92/Yersinia_pestis_CO92_v1.fa

You can also be less specific, omitting version numbers, for example:

  % pf ref -i Yersinia_pestis
  /scratch/pathogen/refs/Yersinia/pestis_CO92/Yersinia_pestis_CO92_v1.fa

You can also use spaces instead of underscores in the name, but you will
need to put the name in quotes, to avoid it being misinterpreted:

  % pf ref -i 'Yersinia pestis'
  /scratch/pathogen/refs/Yersinia/pestis_CO92/Yersinia_pestis_CO92_v1.fa

Finally, searches are case insensitive:

  % pf ref -i 'yersinia pestis'
  /scratch/pathogen/refs/Yersinia/pestis_CO92/Yersinia_pestis_CO92_v1.fa

=head2 Find reference genomes matching an approximate name

If you don't know the exact name or version of a reference genome, you can
search for references matching an approximate name:

  % pf ref -i yersinia
  No exact match for "yersinia". Did you mean:
  Yersinia_pestis_CO92_v1
  Yersinia_enterocolitica_subsp_enterocolitica_8081_v1

The "fuzzy" matching also handles minor spelling mistakes:

  % pf ref -i yersina
  No exact match for "yersina". Did you mean:
  Yersinia_pestis_CO92_v1
  Yersinia_enterocolitica_subsp_enterocolitica_8081_v1

If the genome that you want is in the list, run the command again with the
exact name to get the path to the sequence file.

=cut

#-------------------------------------------------------------------------------
#- command line options --------------------------------------------------------
#-------------------------------------------------------------------------------

# we don't actually need the "--type" option for reffind, since all we're ever
# going to be looking for is species names. Specify a default value.

option '+type' => (
  default => 'species',
);

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

has '_rf' => (
  is      => 'ro',
  isa     => BioPathFindRefFinder,
  lazy    => 1,
  builder => '_build_rf',
);

sub _build_rf {
  return Bio::Path::Find::RefFinder->new;
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

sub run {
  my $self = shift;

  my $refs = $self->_rf->find_refs($self->_ids->[0]);

  if ( scalar @$refs == 1 ) {
    my $paths = $self->_rf->lookup_paths($refs);
    say $_ for @$paths;
  }
  elsif ( scalar @$refs > 1 ) {
    say q(No exact match for ") . $self->_ids->[0] . q(". )
        . colored( ['bright_white bold'], 'Did you mean:' );
    say $_ for @$refs;
  }
  else {
    say 'No matching reference genomes found. Try a less specific species name.';
  }
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

