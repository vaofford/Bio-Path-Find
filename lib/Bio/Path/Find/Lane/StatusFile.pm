
package Bio::Path::Find::Lane::StatusFile;

# ABSTRACT: a wrapper around job status files

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw( carp );
use Path::Class;
use DateTime;

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

  unless ( defined $self->config_file ) {
    carp 'ERROR: no config file loaded' unless defined $self->config_file;
    return '';
  }

  foreach my $file_re ( keys %{ $self->_file_mapping } ) {
    return $self->_file_mapping->{$file_re} if $self->config_file =~ m/$file_re/;
  }

  # if we get to here then the status file specified a valid, found-on-disk
  # config file, but that config file doesn't match any of the known
  # pipelines in the _file_mapping. That suggests it's a new, or otherwise
  # unknown, pipeline, so we should at least warn about it.
  carp "ERROR: unrecognised pipeline in config file";
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

  my @lines = $self->status_file->slurp(chomp => 1);

  unless ( scalar @lines == 4 ) {
    carp 'WARNING: not a valid status file (' . $self->status_file . ')';
    return;
  }

  my $config_file = file $lines[0];
  my @file_stat   = stat $self->status_file;

  $self->_set_config_file( $config_file ) if -f $config_file;
  $self->_set_last_update( $file_stat[9] );
  $self->_set_current_status( $lines[2] );
  $self->_set_number_of_attempts( $lines[3] );
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

