
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

use Bio::Path::Find::Types qw( :types );

extends 'Bio::Path::Find::App::PathFind';

#-------------------------------------------------------------------------------
#- usage text ------------------------------------------------------------------
#-------------------------------------------------------------------------------

# this is used when the "pf" app class builds the list of available commands
command_short_description 'Find information about samples';

# the module POD is used when the users runs "pf man info"

=head1 NAME

pf info - Find information about samples

=head1 USAGE

  pf info --id <id> --type <ID type> [options]

=head1 DESCRIPTION

This pathfind command will return information about samples associated with
sequencing runs. Specify the type of data using C<--type> and give the
accession, name or identifier for the data using C<--id>.

Use "pf man" or "pf man info" to see more information.

=head1 EXAMPLES

  # get sample info for a set of lanes
  pf info -t lane -i 10018_1

  # write info to a CSV file
  pf info -t lane -i 10018_1 -o info.csv

=head1 OPTIONS

These are the options that are specific to C<pf info>. Run C<pf man> to see
information about the options that are common to all C<pf> commands.

=over

=item --outfile, -o [<output filename>]

Write the information to a CSV-format file. If a filename is given, write info
to that file, or to C<infofind.csv> otherwise.

=back

=head1 SCENARIOS

=head2 Show info about samples

The C<pf info> command prints five columns of data for each lane, showing data
about each sample from the tracking and sequencescape databases:

=over

=item lane

=item sample

=item supplier name

=item public name

=item strain

=back

=head2 Write a CSV file

By default C<pf info> simply prints the data that it finds. You can write out a
comma-separated values file (CSV) instead, using the C<--outfile> (C<-o>)
options:

  % pf info -t lane -i 10018_1 -o my_info.csv
  Wrote info to "my_info.csv"

If you don't specify a filename, the default is C<infofind.csv>:

  % pf info -t lane -i 10018_1 -o
  Wrote info to "infofind.csv"

=head2 Write a tab-separated file (TSV)

You can also change the separator used when writing out data. By default we
use comma (,), but you can change it to a tab-character in order to make the
resulting file more readable:

  pf info -t lane -i 10018_1 -o -c "<tab>"

(To enter a tab character you might need to press ctrl-V followed by tab.)

=head1 SEE ALSO

=over

=item pf data - find data files

=item pf status - find the status of samples in the processing pipelines

=back

=cut

#-------------------------------------------------------------------------------
#- command line options --------------------------------------------------------
#-------------------------------------------------------------------------------

# this option can be used as a simple switch ("-o") or with an argument
# ("-o mydir"). It's a bit fiddly to set that up...

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
# a filename, or a string, in which case we'll treat that string as a filename.
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
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

# this is the name of the sequencescape database in the config that defines the
# database connection parameters:
#
#   <connection_params>
#     <tracking>
#       ...
#     </tracking>
#     <sequencescape>
#       driver        SQLite
#       dbname        seqw.db
#       schema_class  Bio::Sequencescape::Schema
#       no_db_root    1
#     </sequencescape>
#   </connection_params>
#
# The default is "sequencescape". If you give a non-default value for
# "sequencescape_schema_name", make sure you name the corresponding section in
# the config the same.

has 'sequencescape_schema_name' => (
  is      => 'ro',
  isa     => Str,
  default => 'sequencescape',
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
    schema_name => $self->sequencescape_schema_name,
    # this should match the name of the configuration section under
    # "connection_params"
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

  # the database manager builds a hash containing B::P::F::Database objects
  # for each of the databases that it finds for a given set of connection
  # parameters. For example, this config:
  #
  #  connection_params => {
  #   track_db => {  ...  },
  #   ss => { ... },
  # }
  #
  # defines two sets of connection parameters. If we create a DB manager and
  # set "sequencescape_schema_name" to "ss", it will build a hash containing
  # all of the databases it can find using those connection params.
  #
  # If the DB manager is talking to a MySQL instance, there will be a
  # B::P::F::Database for every database it finds in the instance, keyed on the
  # database name. In that case we can ask for the database by name,
  # "sequencescape_warehouse".
  #
  # If the DB manager is talking to an SQLite DB, there will be one
  # B::P::F::Database, with the key being the basename of the DB file after the
  # suffix is removed, i.e. a DB called t/data/sequencescape_warehouse.db will
  # have the key "sequencescape_warehouse" in the hash returned by
  # $db_manager->databases. In that case, we can't ask for it by name, because
  # the name comes from the name of the database file, so instead we rely on
  # the fact that there's only going to one sequencescape database if the drive
  # is SQLite.

  my $db;

  if ( $self->config->{connection_params}->{$self->sequencescape_schema_name}->{driver} eq 'SQLite' ) {
    # (checking against the config like this is still pretty ugly)
    ( $db ) = $self->_ss_db_mgr->all_databases;
  }
  else {
    $db = $self->_ss_db_mgr->get_database('sequencescape_warehouse');
  }

  return $db;
}

sub _get_current_sample {
  my $self = $_[0];
  my $lane = $_[1];
  # get ssid to gather information 
  my $ssid = $lane->row
                    ->latest_library
                      ->latest_sample
                        ->ssid;

  # and get the corresponding row in sequencescape_warehouse.current_sample
  my $row = $self->_ss_db
                     ->schema
                       ->resultset('CurrentSample')
                         ->find( { internal_id => $ssid  } );       

  return $row;              
}

sub _get_sample_name {
  my $self = $_[0];
  my $lane = $_[1];

  # get the sample name in case the ssid matches an internal_id but name does not 
  my $name = $lane->row
                      ->latest_library
                        ->latest_sample
                          ->name;

  return($name);
}

sub _get_lane_info {
  my $self = $_[0];
  my $lane = $_[1];

  my $row = $self->_get_current_sample($lane);
  my $name = $self->_get_sample_name($lane);

  my @lane_info = [
                    $lane->row->name,
                    $lane->row->latest_library->latest_sample->name,
                    defined($row) && $row->name eq $name ? ($row->supplier_name || 'NA') : 'NA',
                    defined($row) && $row->name eq $name ? ($row->public_name || 'NA') : 'NA',
                    defined($row) && $row->name eq $name ? ($row->strain || 'NA') : 'NA',
                  ];

  return @lane_info;
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

sub run {
  my $self = shift;

  # if we're writing to file, check that the output file doesn't exist. If we
  # leave it to _write_csv to check, we could end up searching for lanes for
  # hours and THEN fail, which would leave the user mildly updset. Better to
  # fail early, before we've done any work at all.
  if ( $self->_outfile_flag and -f $self->_outfile and not $self->force ) {
    Bio::Path::Find::Exception->throw(
      msg => q(ERROR: CSV file ") . $self->_outfile . q(" already exists; not overwriting existing file)
    );
  }

  # find lanes
  my $lanes = $self->_finder->find_lanes(
    ids  => $self->_ids,
    type => $self->_type,
  );

  my $pb = $self->_create_pb('collecting info', scalar @$lanes);

  # gather the info. We could collect and print the info in the same loop, but
  # then we wouldn't be able to show the progress bar, which is probably worth
  # doing. Instead we'll print in a separate loop at the end.

  # start with headers
  my @info = (
    [ 'Lane', 'Sample', 'Supplier Name', 'Public Name', 'Strain' ]
  );

  foreach my $lane ( @$lanes ) {
    my @lane_info = $self->_get_lane_info($lane);
    push @info, @lane_info;
    $pb++;
  }

  # write a CSV file or print to STDOUT
  if ( $self->_outfile_flag ) {
    $self->_write_csv( \@info, $self->_outfile );
    say STDERR q(Wrote info to ") . $self->_outfile . q(");
  }
  else {
    # fix the formats of the columns so that everything lines up
    # (printf format patterned on the one from the old infofind;
    # ditched the trailing spaces...)
    printf "%-15s %-25s %-25s %-25s %s\n", @$_ for @info;
  }

}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

