
package Bio::Path::Find::Lane::StatusFile;

# ABSTRACT: a wrapper around job status files

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw( carp );
use Path::Class;
use DateTime;
use Try::Tiny;

use Types::Standard qw(
  HashRef
  Str
  Int
);
use Bio::Path::Find::Types qw(
  PathClassFile
  Datetime
);

use Bio::Path::Find::Exception;

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

# required attributes

has 'status_file' => (
  is       => 'ro',
  isa      => PathClassFile,
  required => 1,
);

#---------------------------------------

# attributes populated when we read a file

# NOTE the "config_file" referred to throughout this class is not the config
# NOTE file for the Bio::Path::Find classes, but a config file that's part of
# NOTE the pipeline system

has 'config_file'        => ( is => 'ro', isa => PathClassFile, writer => '_set_config_file' );
has 'last_update'        => ( is => 'ro', isa => Datetime,      writer => '_set_last_update',       coerce => 1 );
# (coerce from an epoch time in the status file)
has 'current_status'     => ( is => 'ro', isa => Str,           writer => '_set_current_status' );
has 'number_of_attempts' => ( is => 'ro', isa => Int,           writer => '_set_number_of_attempts' );

has 'pipeline_name' => (
  is      => 'ro',
  isa     => Str,
  lazy    => 1,
  builder => '_build_pipeline_name',
);

sub _build_pipeline_name {
  my $self = shift;

  return '' unless ( defined $self->config_file and
                     -f $self->config_file );

  foreach my $file_re ( keys %{ $self->_file_mapping } ) {
    return $self->_file_mapping->{$file_re} if $self->config_file =~ m/$file_re/;
  }
  return '';
}

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# maps a component of the name of a status file to the pipeline name

has '_file_mapping' => (
  is      => 'ro',
  isa     => HashRef[Str],
  default => sub {
    {
    # file regex           pipeline name
      import            => 'import',
      mapping           => 'mapped',
      qc                => 'qc',
      stored            => 'stored',
      rna_seq           => 'rna_seq_expression',
      snps              => 'snp_called',
      assembly          => 'assembled',
      annotate_assembly => 'annotated',
    };
  },
);

#-------------------------------------------------------------------------------
#- constructor -----------------------------------------------------------------
#-------------------------------------------------------------------------------

sub BUILD {
  my $self = shift;

  unless ( -f $self->status_file ) {
    Bio::Path::Find::Exception->throw(
      msg =>  q(ERROR: can't find status file ") . $self->status_file . q(")
    );
  }

  my $read_error = 0;
  my @lines;
  
  return unless (-r $self->status_file );
  
  try {
    @lines = $self->status_file->slurp(chomp => 1);
  } catch {
    $read_error++;
  };
  return if $read_error;

  unless ( scalar @lines == 4 ) {
    carp 'WARNING: not a valid job status file (' . $self->status_file . ')';
    return;
  }

  my $config_file = file $lines[0];
  my @file_stat   = stat $self->status_file;

  $self->_set_config_file( $config_file );
  $self->_set_last_update( $file_stat[9] );
  $self->_set_current_status( $lines[2] );
  $self->_set_number_of_attempts( $lines[3] );
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

