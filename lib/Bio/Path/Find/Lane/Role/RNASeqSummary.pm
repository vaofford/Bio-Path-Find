
package Bio::Path::Find::Lane::Role::RNASeqSummary;

# ABSTRACT: a role that provides methods for retrieving and formatting RNASeq summary for lanes

use Moose::Role;

use Path::Class;

use Types::Standard qw(
  ArrayRef
  HashRef
  Str
  Int
  Bool
  +Num
);

use Bio::Path::Find::Types qw(
  BioTrackSchemaResultBase
);

requires '_build_summary_headers',
         '_build_summary';

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=attr headers

Reference to an array containing column headers for summary output.

=cut

has 'summary_headers' => (
  is      => 'ro',
  isa     => ArrayRef[Str],
  lazy    => 1,
  builder => '_build_summary_headers',
);

#---------------------------------------

=attr summary

Reference to an array containing ssummary. Column order is the same as in
L<headers>.

=cut

has 'summary' => (
  is      => 'ro',
#  isa     => ArrayRef[ArrayRef],
  lazy    => 1,
  builder => '_build_summary',
);


#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

1;