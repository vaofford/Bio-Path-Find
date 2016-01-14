
package Bio::Path::Find::App::PathFind::Accession;

# ABSTRACT: find accessions

use v5.10; # for "say"

use MooseX::App::Command;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Path::Class;

use Types::Standard qw(
  Bool
);

use Bio::Path::Find::Types qw(
  PathClassFile FileFromStr
);

extends 'Bio::Path::Find::App::PathFind';

#-------------------------------------------------------------------------------
#- usage text ------------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 USAGE

pf accession --id <id> --type <ID type> [options]

=head1 DESCRIPTION

Given a study ID, lane ID, or sample ID, or a file containing a list of IDs,
this script will return the accessions associated with the specified lane(s).

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

option 'fastq' => (
  documentation => 'generate URLs for downloading fastq files from ENA',
  is            => 'ro',
  isa           => Bool,
  cmd_aliases   => 'f',
);

option 'submitted' => (
  documentation => 'generate URLs for downloading submitted files from ENA',
  is            => 'ro',
  isa           => Bool,
  cmd_aliases   => 's',
);

option 'outfile' => (
  documentation => 'write output to file',
  is            => 'rw',
  isa           => PathClassFile->plus_coercions(FileFromStr),
  cmd_aliases   => 'o',
  default       => sub { file 'accessionfind.out' },
);

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 run

Find accessions according to the input parameters.

=cut

sub run {
  my $self = shift;

  say 'finding accessions...';
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

