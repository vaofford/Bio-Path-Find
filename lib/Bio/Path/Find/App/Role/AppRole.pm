
package Bio::Path::Find::App::Role::AppRole;

# ABSTRACT: a role that carries most of the boilerplate for "finder" apps

use Moose::Role;

use Path::Class;
use Carp qw( croak );

use Types::Standard qw(
  ArrayRef
  Str
  Bool
);

use Bio::Path::Find::Types qw(
  Environment
  IDType
  FileIDType
  BioPathFindFinder
  PathClassFile
);

use Bio::Path::Find::Finder;

with 'MooseX::Getopt::Usage',
     'MooseX::Log::Log4perl',
     'Bio::Path::Find::Role::HasConfig',
     'Bio::Path::Find::Role::HasEnvironment';

requires 'run';

#-------------------------------------------------------------------------------
#- common attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

# these are attributes that are common to all roles. Attributes that are
# specific to one particular application go in the concrete app class.

# the values of these attributes are taken from the command line options, which
# are set up by the "new_with_options" call that instantiates the *Find object
# in the main script, e.g. pathfind

has 'id' => (
  documentation => 'ID or name of file containing IDs',
  is            => 'rw',
  isa           => Str,
  cmd_aliases   => 'i',
  required      => 1,
  traits        => ['Getopt'],
);

has 'type' => (
  documentation => 'ID type, or "file" for IDs in a file',
  is            => 'rw',
  isa           => IDType,
  cmd_aliases   => 't',
  required      => 1,
  traits        => ['Getopt'],
);

has 'file_id_type' => (
  documentation => 'type of IDs in the input file',
  is            => 'rw',
  isa           => FileIDType,
  cmd_aliases   => 'ft',
  traits        => ['Getopt'],
);

has 'verbose' => (
  documentation => 'show debugging messages',
  is            => 'rw',
  isa           => Bool,
  cmd_aliases   => 'v',
  default       => 0,
  traits        => ['Getopt'],
);

# these are "non-option" attributes
has 'environment'  => ( is => 'rw', isa => Environment, default => 'prod' );
has 'config_file'  => ( is => 'rw', isa => Str,         default => 'live.conf' );
# TODO get rid of the hard-coded config file path somehow

# configure the usage message. This method is used by MooseX::Getopt::Usage to
# determine which POD sections are used to build the usage message, i.e. the
# DESCRIPTION section from the POD in the concrete application class, e.g.
# Bio::Path::Find::App::PathFind, provides the usage message.
#
# If we miss this method out, MooseX::Getopt will auto-generate the options
# list, which is in hash order and shows all attributes, not just the command
# line options

sub getopt_usage_config {
  return ( usage_sections => [ 'DESCRIPTION' ] );
}

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# these are just internal slots to hold the real list of IDs and the correct
# ID type, after we've worked out what the user is handing us by examining the
# input parameters in "sub BUILD"
has '_ids' => (  is => 'rw', isa => ArrayRef[Str] );
has '_type' => ( is => 'rw', isa => IDType );

#---------------------------------------

# set the location of the log file. The file path is taken from the config and
# is different depending on whether we're in test mode or not

has '_log_file' => (
  is      => 'ro',
  isa     => PathClassFile,
  lazy    => 1,
  builder => '_build_log_file',
);

sub _build_log_file {
  my $self = shift;

  my $config_file = $self->is_in_test_env
                  ? $self->config->{test_logfile}
                  : $self->config->{logfile};

  return file($config_file);
}

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

  my $LOGFILE = $self->_log_file;
  my $LEVEL   = $self->verbose ? 'DEBUG' : 'WARN';

  my $config_string = qq(

    # appenders

    # an appender to log the command line to file
    log4perl.appender.File                             = Log::Log4perl::Appender::File
    log4perl.appender.File.layout                      = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.File.layout.ConversionPattern    = %d %m%n
    log4perl.appender.File.filename                    = $LOGFILE
    log4perl.appender.File.Threshold                   = INFO

    log4perl.appender.Screen                           = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.layout                    = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Screen.layout.ConversionPattern  = %M:%L %p: %m%n

    # loggers

    # general debugging
    log4perl.logger.Bio.Path.Find.App.TestFind         = $LEVEL, Screen
    log4perl.logger.Bio.Path.Find.App.PathFind         = $LEVEL, Screen
    log4perl.logger.Bio.Path.Find.Finder               = $LEVEL, Screen
    log4perl.logger.Bio.Path.Find.Lane                 = $LEVEL, Screen
    log4perl.logger.Bio.Path.Find.DatabaseManager      = $LEVEL, Screen

    # command line logging
    log4perl.logger.command_log                        = INFO, File

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

  return Bio::Path::Find::Finder->new(
    config      => $self->config,
    environment => $self->environment,
  );
}

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
  croak q(ERROR: if "type" is "file", you must also specify "file_id_type")
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

# log the command line to file

sub _log_command {
  my $self = shift;

  my $command_line = join ' ', $0, @ARGV;

  $self->log('command_log')->info($command_line);
}

#-------------------------------------------------------------------------------

sub _load_ids_from_file {
  my ( $self, $filename ) = @_;

  croak "ERROR: no such file ($filename)" unless -f $filename;

  # TODO check if this will work with the expected usage. If users are used
  # TODO to putting plex IDs as search terms, stripping lines starting with
  # TODO "#" will break those searches
  my @ids = grep ! m/^#/, $filename->slurp(chomp => 1);

  croak "ERROR: no IDs found in file ($filename)" unless scalar @ids;

  return \@ids;
}

#-------------------------------------------------------------------------------

1;

