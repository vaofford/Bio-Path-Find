
package Bio::Path::Find::App::Role::AppRole;

# ABSTRACT: a role that carries most of the boilerplate for "finder" apps

use Moose::Role;
use MooseX::App::Role;

use Path::Class;
use Text::CSV_XS;
use Try::Tiny;
use FileHandle;

use Types::Standard qw(
  ArrayRef
  Str
  Bool
);

use Bio::Path::Find::Types qw(
  IDType
  FileIDType
  BioPathFindFinder
  PathClassFile
);

use Bio::Path::Find::Finder;
use Bio::Path::Find::Exception;

with 'MooseX::Log::Log4perl',
     'Bio::Path::Find::Role::HasConfig';

# this is the one and only method that the concrete find class needs to provide
requires 'run';

#-------------------------------------------------------------------------------
#- common attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

# these are attributes that are common to all roles. Attributes that are
# specific to one particular application go in the concrete app class.

# the values of these attributes are taken from the command line options, which
# are set up by the "new_with_options" call that instantiates the *Find object
# in the main script, e.g. pathfind

option 'id' => (
  documentation => 'ID or name of file containing IDs',
  is            => 'rw',
  isa           => Str,
  cmd_aliases   => 'i',
  required      => 1,
  trigger       => sub {
    my ( $self, $id ) = @_;
    ( my $renamed_id = $id ) =~ s/\#/_/g;
    $self->_renamed_id( $renamed_id );
  },
);

option 'type' => (
  documentation => 'ID type. Use "file" to read IDs from file',
  is            => 'rw',
  isa           => IDType,
  cmd_aliases   => 't',
  required      => 1,
);

option 'file_id_type' => (
  documentation => 'type of IDs in the input file',
  is            => 'rw',
  isa           => FileIDType,
  cmd_flag      => 'file-id-type',
  cmd_aliases   => 'ft',
);

option 'csv_separator' => (
  documentation => 'field separator to use when writing CSV files',
  is            => 'rw',
  isa           => Str,
  cmd_flag      => 'csv-separator',
  cmd_aliases   => 'c',
  default       => ',',
);

option 'no_progress_bars' => (
  documentation => "don't show progress bars",
  is            => 'ro',
  isa           => Bool,
  cmd_flag      => 'no-progress-bars',
  cmd_aliases   => 'n',
  trigger       => sub {
    my ( $self, $flag ) = @_;
    # set a flag on the config object to tell interested objects whether they
    # should show progress bars when doing work
    $self->config->{no_progress_bars} = $flag;
  },
);

option 'verbose' => (
  documentation => 'show debugging messages',
  is            => 'rw',
  isa           => Bool,
  cmd_aliases   => 'v',
  default       => 0,
);

# these are "non-option" attributes
# has 'config_file'  => ( is => 'rw', isa => Str, default => 'live.conf' );
# TODO get rid of the hard-coded config file path somehow

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# these are just internal slots to hold the real list of IDs and the correct
# ID type, after we've worked out what the user is handing us by examining the
# input parameters in "sub BUILD"
has '_ids' => (  is => 'rw', isa => ArrayRef[Str] );
has '_type' => ( is => 'rw', isa => IDType );

#---------------------------------------

# define the configuration for the Log::Log4perl logger

has '_logger_config' => (
  is      => 'ro',
  isa     => 'Ref',
  lazy    => 1,
  builder => '_build_logger_config',
);

sub _build_logger_config {
  my $self = shift;

  my $LEVEL = $self->verbose ? 'DEBUG' : 'WARN';

  my $config_string = qq(

    # appenders

    log4perl.appender.Screen                           = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.layout                    = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Screen.layout.ConversionPattern  = %M:%L %p: %m%n

    # loggers

    # set log levels for individual classes
    log4perl.logger.Bio.Path.Find.App.TestFind         = $LEVEL, Screen
    log4perl.logger.Bio.Path.Find.App.PathFind         = $LEVEL, Screen
    log4perl.logger.Bio.Path.Find.Finder               = $LEVEL, Screen
    log4perl.logger.Bio.Path.Find.Lane                 = $LEVEL, Screen
    log4perl.logger.Bio.Path.Find.DatabaseManager      = $LEVEL, Screen

    log4perl.oneMessagePerAppender                     = 1
  );

  return \$config_string;
}

#---------------------------------------

has '_finder' => (
  is      => 'ro',
  isa     => BioPathFindFinder,
  lazy    => 1,
  builder => '_build_finder',
);

sub _build_finder {
  my $self = shift;
  return Bio::Path::Find::Finder->new(config => $self->config);
}

#---------------------------------------

# a slot to store the ID, but with hashes converted to underscores. Written by
# a trigger on the "id" attribute

has '_renamed_id' => (
  is => 'rw',
  isa => Str,
);

#-------------------------------------------------------------------------------
#- construction ----------------------------------------------------------------
#-------------------------------------------------------------------------------

sub BUILD {
  my $self = shift;

  # initialise the logger
  Log::Log4perl->init_once($self->_logger_config);

  $self->log->debug('verbose logging is on');
  # (should only appear when "-verbose" is used)

  # if "-verbose" is used multiple times, turn on DBIC query logging too
  $ENV{DBIC_TRACE} = 1 if $self->verbose > 1;

  # check for dependencies between parameters: if "type" is "file", we need to
  # know what type of IDs we'll find in the file
  Bio::Path::Find::Exception->throw( msg => q(ERROR: if "type" is "file", you must also specify "file_id_type") )
    if ( $self->type eq 'file' and not $self->file_id_type );

  # look at the input parameters and decide whether we're dealing with a single
  # ID or many, and what the type of the ID(s) is/are
  my ( $ids, $type );

  if ( $self->type eq 'file' ) {
    # read multiple IDs from a file
    $ids  = $self->_load_ids_from_file( file($self->id) );
    $type = $self->file_id_type;

    $self->log->debug('found ' . scalar @$ids . qq( IDs from file "$ids")
                      . qq(, of type "$type") );
  }
  else {
    # use the single ID from the command line
    $ids  = [ $self->id ];
    $type = $self->type;

    $self->log->debug(  qq(looking for single ID, "$ids", of type "$type") );
  }

  $self->_ids($ids);
  $self->_type($type);
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# logs the command line to file

sub _log_command {
  my $self = shift;

  my $username     = ( getpwuid($<) )[0];
  my $command_line = join ' ', $username, $0, @ARGV;

  $self->log('command_log')->info($command_line);
}

#-------------------------------------------------------------------------------

# reads a list of IDs from the supplied filename. Treats lines beginning with
# hash (#) as comments and ignores them

sub _load_ids_from_file {
  my ( $self, $filename ) = @_;

  Bio::Path::Find::Exception->throw( msg => "ERROR: no such file ($filename)" )
    unless -f $filename;

  # TODO check if this will work with the expected usage. If users are used
  # TODO to putting plex IDs as search terms, stripping lines starting with
  # TODO "#" will break those searches
  my @ids = grep ! m/^#/, $filename->slurp(chomp => 1);

  Bio::Path::Find::Exception->throw( msg => "ERROR: no IDs found in file ($filename)" )
    unless scalar @ids;

  return \@ids;
}

#-------------------------------------------------------------------------------

# writes the supplied array of arrays in CSV format to the specified file.
# Uses the separator specified by the "csv_separator" attribute

sub _write_stats_csv {
  my ( $self, $stats, $filename ) = @_;

  return unless ( defined $stats and scalar @$stats );

  Bio::Path::Find::Exception->throw( msg => 'ERROR: must supply a filename for the stats report' )
    unless defined $filename;

  my $fh = FileHandle->new;

  # see if the supplied filename exists and complain if it does
  Bio::Path::Find::Exception->throw( msg => 'ERROR: stats CSV file already exists; not overwriting existing file' )
    if -e $filename;

  $fh->open( $filename, '>' );

  my $csv = Text::CSV_XS->new;
  $csv->eol("\n");
  $csv->sep( $self->csv_separator );
  $csv->print($fh, $_) for @$stats;

  $fh->close;
}

#-------------------------------------------------------------------------------

1;

