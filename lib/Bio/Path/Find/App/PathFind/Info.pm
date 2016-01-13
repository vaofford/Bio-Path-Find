
package Bio::Path::Find::App::PathFind::Info;

# ABSTRACT: Find information about samples

use v5.10; # for "say"

use MooseX::App::Command;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw ( carp );
use Path::Class;
use Try::Tiny;

use Types::Standard qw(
  ArrayRef
  Str
  +Bool
);

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

# option 'outfile' => (
#   documentation => 'write output to file',
#   is            => 'rw',
#   isa           => PathClassFile->plus_coercions(FileFromStr),
#   cmd_aliases   => 'o',
#   cmd_env       => 'PF_OUTFILE',
#   default       => sub { file 'infofind.out' },
# );

#---------------------------------------

# this option can be used as a simple switch ("-l") or with an argument
# ("-l mydir"). It's a bit fiddly to set that up...

option 'outfile' => (
  documentation => 'write info to a CSV file',
  is            => 'ro',
  cmd_aliases   => 'o',
  cmd_env       => 'PF_OUTFILE',
  trigger       => \&_check_for_outfile_value,
  # no "isa" because we want to accept both Bool and Str and it doesn't seem to
  # be possible to specify that using the combination of MooseX::App and
  # Type::Tiny that we're using here
);

# set up a trigger that checks for the value of the "outfile" command-line
# argument and tries to decide if it's a boolean, in which case we'll generate
# a directory name to hold links, or a string, in which case we'll treat that
# string as a directory name.
sub _check_for_outfile_value {
  my ( $self, $new, $old ) = @_;

  if ( not defined $new ) {
    # write info to file specified by the user
    $self->_outfile_flag(1);
  }
  elsif ( not is_Bool($new) ) {
    # write info to file specified by the user
    $self->_outfile_flag(1);
    $self->_outfile( file $new );
  }
  else {
    # don't write file. Shouldn't ever get here
    $self->_outfile_flag(0);
  }
}

# private attributes to store the (optional) value of the "outfile" attribute.
# When using all of this we can check for "_outfile_flag" being true or false,
# and, if it's true, check "_outfile" for a value
has '_outfile'      => ( is => 'rw', isa => PathClassFile, default => sub { file 'infofind.csv' } );
has '_outfile_flag' => ( is => 'rw', isa => Bool );

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

  # if we're writing to file, check that the output file doesn't exist. If we
  # leave it to _write_csv to check, we could end up searching for lanes for
  # hours and THEN fail, which would leave the user mildly updset. Better to
  # fail early, before we've done any work at all.
  if ( $self->_outfile_flag and -f $self->_outfile ) {
    Bio::Path::Find::Exception->throw(
      msg => q(ERROR: CSV file ") . $self->_outfile . q(" already exists; not overwriting existing file)
    );
  }

  # find lanes
  my $lanes = $self->_finder->find_lanes(
    ids  => $self->_ids,
    type => $self->type,
  );

  my $pb = $self->config->{no_progress_bars}
         ? 0
         : Term::ProgressBar::Simple->new( {
             name   => 'collecting info',
             count  => scalar @$lanes,
             remove => 1,
           } );

  # gather the info. We could collect and print the info in the same loop, but
  # then we wouldn't be able to show the progress bar, which is probably worth
  # doing. Instead we'll print in a separate loop at the end.

  # start with headers
  my @info = (
    [ 'Lane', 'Sample', 'Supplier Name', 'Public Name', 'Strain' ]
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

    push @info, [
      $lane->row->name,
      $lane->row->latest_library->latest_sample->name,
      $row->supplier_name || 'NA',
      $row->public_name || 'NA',
      $row->strain || 'NA',
    ];

    $pb++;
  }

  # write a CSV file or print to STDOUT
  if ( $self->_outfile_flag ) {
    $self->_write_csv( \@info, $self->_outfile );
    say STDERR q(Wrote info to ") . $self->_outfile . q(");
  }
  else {
    # fix the formats of the columns so that everything lines up
    # (printf format taken from the old pathfind)
    printf "%-15s %-25s %-25s %-25s %-20s\n", @$_ for @info;
  }

}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

