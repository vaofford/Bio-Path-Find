
package Bio::Path::Find::App::PathFind::Info;

# ABSTRACT: Find information about samples

use v5.10; # for "say"

use MooseX::App::Command;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw ( carp );
use Path::Class;
use Try::Tiny;

use Bio::Path::Find::Types qw(
  PathClassFile FileFromStr
);

extends 'Bio::Path::Find::App::PathFind';

with 'Bio::Path::Find::App::Role::AppRole';

#-------------------------------------------------------------------------------
#- usage text ------------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 USAGE

pf info --id <id> --type <ID type> [options]

=head1 DESCRIPTION

Given a study ID, lane ID, or sample ID, or a file containing a list of IDs,
this script will return information about the samples for the specified
lane(s).

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

option 'outfile' => (
  documentation => 'write output to file',
  is            => 'rw',
  isa           => PathClassFile->plus_coercions(FileFromStr),
  cmd_aliases   => 'o',
  cmd_env       => 'PF_OUTFILE',
  default       => sub { file 'infofind.out' },
);

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 run

Find information about samples according to the input parameters.

=cut

sub run {
  my $self = shift;

  say 'finding info...';

  # my $finder_params = (
  #   ids  => $self->_ids,
  #   type => $self->type,
  # );
  #
  # my $lanes = $self->_finder->find_lanes(%finder_params);
  #
  # foreach my $lane ( @$lanes ) {
  #   my $ssid = $lane->ssid;
  #   my $rs = $self->_
  #   
  # }


}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

