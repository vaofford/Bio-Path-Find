
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
  BioPathFindDatabaseManager
  BioPathFindDatabase
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
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

has '_ss_db_mgr' => (
  is      => 'ro',
  isa     => BioPathFindDatabaseManager,
  lazy    => 1,
  builder => '_build_ss_db_mgr',
);

sub _build_ss_db_mgr {
  my $self = shift;

  return Bio::Path::Find::DatabaseManager->new(
    config      => $self->config,
    schema_name => 'sequencescape',
  );
}

#---------------------------------------

has '_ss_db' => (
  is      => 'ro',
  isa     => BioPathFindDatabase,
  lazy    => 1,
  builder => '_build_ss_db',
);

sub _build_ss_db {
  my $self = shift;

  return $self->_ss_db_mgr->get_database('sequencescape_warehouse');
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 run

Find information about samples according to the input parameters.

=cut

sub run {
  my $self = shift;

  my $lanes = $self->_finder->find_lanes(
    ids  => $self->_ids,
    type => $self->type,
  );

  foreach my $lane ( @$lanes ) {
    # walk across the relationships between the latest_lane and latest_sample
    # tables, to get the SSID
    my $ssid = $lane->row
                      ->latest_library
                        ->latest_sample
                          ->ssid;

    # and get the corresponding row in sequencescape_warehouse.current_sample
    my $row = $self->_ss_db->schema->resultset('CurrentSample')->find( { internal_id => $ssid } );

    print $lane->row->name, "\t";
    print $lane->row->latest_library->latest_sample->name, "\t";
    print $row->supplier_name || 'na', "\t";
    print $row->public_name || 'na', "\t";
    print $row->strain || 'na', "\n";
  }

}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

