
package Bio::Path::Find::App::Role::AppRole;

# ABSTRACT: a role the carries most of the boilerplate for "finder" apps

use Moose::Role;

use Path::Class;
use Carp qw( croak );

use Types::Standard qw(
  Str
  Bool
);

use Bio::Path::Find::Types qw(
  Environment
  IDType
  FileType
  FileIDType
  QCState
  BioPathFindFinder
  PathClassFile
);

use Bio::Path::Find;

with 'MooseX::Getopt',
     'MooseX::Log::Log4perl',
     'Bio::Path::Find::Role::HasConfig',
     'Bio::Path::Find::Role::HasEnvironment';

requires 'run';

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

# options
has 'id'           => ( is => 'rw', isa => Str,         traits => [ 'Getopt' ], cmd_aliases => 'i', required => 1 );
has 'type'         => ( is => 'rw', isa => IDType,      traits => [ 'Getopt' ], cmd_aliases => 't', required => 1 );
has 'filetype'     => ( is => 'rw', isa => FileType,    traits => [ 'Getopt' ], cmd_aliases => 'f'  );
has 'file_id_type' => ( is => 'rw', isa => FileIDType,  traits => [ 'Getopt' ], cmd_aliases => 'ft' );
has 'qc'           => ( is => 'rw', isa => QCState,     traits => [ 'Getopt' ], cmd_aliases => 'q'  );
has 'symlink'      => ( is => 'rw', isa => Str,         traits => [ 'Getopt' ], cmd_aliases => 'l'  );
has 'stats'        => ( is => 'rw', isa => Str,         traits => [ 'Getopt' ], cmd_aliases => 's'  );
has 'rename'       => ( is => 'rw', isa => Bool,        traits => [ 'Getopt' ], cmd_aliases => 'r'  );
has 'archive'      => ( is => 'rw', isa => Bool,        traits => [ 'Getopt' ], cmd_aliases => 'a'  );

has 'verbose'      => ( is => 'rw', isa => Bool,        traits => [ 'Getopt' ], cmd_aliases => 'v', default => 0 );

# non-option attributes
# # TODO get rid of the hard-coded config file path
has 'config_file'  => ( is => 'rw', isa => Str,         traits => [ 'Getopt' ], default => 'live.conf' );
has 'environment'  => ( is => 'rw', isa => Environment, traits => [ 'NoGetopt' ], default => 'prod' );

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

  return \qq(

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
    log4perl.logger.Bio.Path.Find.CommandLine.PathFind = DEBUG, Screen
    log4perl.logger.Bio.Path.Find                      = $LEVEL, Screen
    log4perl.logger.Bio.Path.Find.Finder               = $LEVEL, Screen
    log4perl.logger.Bio.Path.Find.Lane                 = $LEVEL, Screen
    log4perl.logger.Bio.Path.Find.DatabaseManager      = $LEVEL, Screen

    # command line logging
    log4perl.logger.command_log                        = INFO, File

    log4perl.oneMessagePerAppender                     = 1
  );
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

  $ENV{DBIC_TRACE} = 1 if $self->verbose;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# format the command parameters. Prepend the name of the script and add a "-"
# to each option
sub _log_command {
  my $self = shift;

  # these are the command line options that we'll include as part of the
  # command line
  my @options = qw( id type filetype file_id_type qc);

  my $command_line = $0;
  foreach my $opt ( @options ) {
    $command_line .= " -$opt " . $self->$opt if $self->$opt;
  }

  $self->log('command_log')->info($command_line);
}

#-------------------------------------------------------------------------------

sub _tidy_id_and_type {
  my $self = shift;

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

  return ( $ids, $type );
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

