
package Bio::Path::Find::LaneStatusFile;

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw( carp croak );
use File::Slurper qw( read_lines );
use Path::Class;
use DateTime;

use Types::Standard qw(
  HashRef
  Str
  Int
);
use Bio::Path::Find::Types qw(
  BioPathFindLane
  PathClassFile
  Datetime
);

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

# required attributes

has 'lane' => (
  is       => 'ro',
  isa      => BioPathFindLane,
  required => 1,
  handles  => {
    database_status => 'qc_status',
  },
);

has 'status_file' => (
  is       => 'ro',
  isa      => PathClassFile,
  required => 1,
);

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
  foreach my $flag ( keys %{ $self->_flag_mapping } ) {
    return $self->_flag_mapping->{$flag} if $self->config_file =~ m/$flag/;
  }
}

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# maps a component of the name of a status file to the pipeline name

has '_flag_mapping' => (
  is      => 'ro',
  isa     => HashRef[Str],
  default => sub {
    {
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

  croak q(ERROR: can't find status file ") . $self->status_file . q(")
    unless -f $self->status_file;

  my @lines = read_lines $self->status_file;

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

