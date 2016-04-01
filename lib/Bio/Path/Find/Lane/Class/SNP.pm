
package Bio::Path::Find::Lane::Class::SNP;

# ABSTRACT: a class that adds SNP-finding functionality to the B::P::F::Lane class

use v5.10; # for "say"

use Moose;
use Path::Class;
use Carp qw( carp );

use Types::Standard qw(
  Maybe
  Str
  HashRef
  ArrayRef
);

use Bio::Path::Find::Types qw( :all );

extends 'Bio::Path::Find::Lane';

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

# make the "filetype" attribute require values of type SNPType. This is to make
# sure that this class correctly restrict the sorts of files that it will
# return.

has '+filetype' => (
  isa => Maybe[SNPType],
);

#---------------------------------------

has 'mappers' => (
  is      => 'ro',
  isa     => Mappers,
  lazy    => 1,
  builder => '_build_mappers',
);

sub _build_mappers {
  return Mapper->values;
}

#---------------------------------------

=head1 ATTRIBUTES

=attr reference

The name of the reference genome on which to filter returned lanes.

=cut

has 'reference' => (
  is  => 'ro',
  isa => Str,
);

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# somewhere to store extra information about the files that we find. The info
# is stored as hashref, keyed on the file path.

has '_verbose_file_info' => (
  is      => 'rw',
  isa     => HashRef[ArrayRef[Str]],
  default => sub { {} },
);

#-------------------------------------------------------------------------------
#- methods ---------------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 print_details

For each bam file found by this lane, print:

=over

=item the path to the file itself

=item the reference to which reads were mapped

=item the name of the mapping software used

=item the date at which the mapping was generated

=back

The items are printed as a simple tab-separated list, one row per file.

=cut

sub print_details {
  my $self = shift;

  foreach my $file ( $self->all_files ) {
    say join "\t", $file, @{ $self->_verbose_file_info->{$file} };
  }
}

#-------------------------------------------------------------------------------

=head2 get_file_info($file)

Returns a reference to an array containing the details of the specified file.
The file should be the L<Path::Class::File> object that's returned by a call
to C<$lane-E<gt>all_files>. The returned array contains the following fields:

=over

=item reference

The name of the reference genome that was used during mapping

=item mapper

The name of the mapping program

=item timestamp

The time/date at which the mapping was generated

=cut

sub get_file_info {
  my ( $self, $file ) = @_;
  return $self->_verbose_file_info->{$file};
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# given a "from" and "to" filename, edit the destination to change the format
# of the filename. This gives this Lane a chance to edit the filenames that are
# used, so that they can be specialised to assembly data.
#
# For example, this method is called by B::P::F::Role::Linker before it creates
# links. This method makes the link destination look like:
#
#   <dst_path directory> / <id>.<mapstats_id>.mpileup.unfilt.vcf.gz
#
#  e.g. 11657_5#33/11657_5#33.851642.mpileup.unfilt.vcf.gz
#       11657_5#33/11657_5#33.851642.mpileup.unfilt.vcf.gz.tbi

sub _edit_filenames {
  my ( $self, $src_path, $dst_path ) = @_;

  my @src_path_components = $src_path->components;

  my $id_dir      = $src_path_components[-3];
  my $mapping_dir = $src_path_components[-2];
  my $filename    = $src_path_components[-1];

  ( my $mapstats_id = $mapping_dir ) =~ s/^(\d+)\..*$/$1/;

  my $new_dst = file( $dst_path->dir, $id_dir . '.' . $mapstats_id . '_' . $filename );

  return ( $src_path, $new_dst );
}

#-------------------------------------------------------------------------------

# find VCF files for the lane

sub _get_vcf {
  return shift->_get_files('vcf', 'tbi');
}

#---------------------------------------

sub _get_pseudogenome {
  return shift->_get_files('pseudogenome');
}

#-------------------------------------------------------------------------------

# this method is cargo-culted from Bio::Path::Find::Lane::Class::Map, with
# mapping-specific tweaks.

sub _get_files {
  my ( $self, $filetype, $index_suffix ) = @_;

  my $lane_row = $self->row;

  my $mapstats_rows = $lane_row->search_related_rs( 'latest_mapstats', { is_qc => 0 } );

  # if there are no rows for this lane in the mapstats table, it hasn't had
  # mapping run on it, so we're done here
  return unless $mapstats_rows->count;

  MAPPING: foreach my $mapstats_row ( $mapstats_rows->all ) {

    my $mapstats_id = $mapstats_row->mapstats_id;
    my $prefix      = $mapstats_row->prefix;

    # find the path (on NFS) to the job status file for this mapping run
    my $job_status_file = file( $lane_row->storage_path, "${prefix}job_status" );

    # if the job failed or is still running, the file "<prefix>job_status" will
    # still exist, in which case we don't want to return *any* bam files
    next MAPPING if -f $job_status_file;

    # at this point there's no job status file, so the mapping job is done

    #---------------------------------------

    # apply filters

    # this is the mapper that was actually used to map this lane's reads
    my $lane_mapper = $mapstats_row->mapper->name;

    # this is the reference that was used for this particular mapping
    my $lane_reference = $mapstats_row->assembly->name;

    # return only mappings generated using a specific mapper
    if ( $self->mappers ) {
      # the user provided a list of mappers. Convert it into a hash so that
      # we can quickly look up the lane's mapper in there
      my %wanted_mappers = map { $_ => 1 } @{ $self->mappers };

      # unless the lane's mapper is one of the mappers that the user specified,
      # skip this mapping
      next MAPPING unless exists $wanted_mappers{$lane_mapper};
    }

    # return only mappings that use a specific reference genome
    next MAPPING if ( $self->reference and $lane_reference ne $self->reference );

    #---------------------------------------

    # build the name of the file(s) for this mapping

    # single or paired end ?
    my $pairing = $lane_row->paired ? 'pe' : 'se';

    my $mapping_dir = "$mapstats_id.$pairing.markdup.snp";
    my $file = $filetype eq 'vcf'
             ? 'mpileup.unfilt.vcf.gz'
             : 'pseudo_genome.fasta';

    my $returned_file = file($self->symlink_path, $mapping_dir, $file);

    # if the VCF file exists, we show that. Note that we check that the file
    # exists using the storage path (on NFS), but return the symlink path (on
    # lustre)
    if ( -f file($self->storage_path, $mapping_dir, $file) ) {
      # store the file itself, plus some extra details, which are used by the
      # "print_details" method
      $self->_add_file($returned_file);
      $self->_verbose_file_info->{$returned_file} = [
        $lane_reference,          # name of the reference
        $lane_mapper,             # name of the mapper
        $mapstats_row->changed,   # last update timestamp
      ];
    }
    else {
      say STDERR qq(WARNING: couldn't find file "$mapping_dir/$file"; mapping $mapstats_id may not be finished?);
    }

    # VCF files come with an index (".tbi"), which we want to add to archives
    # along with the VCF itself
    if ( $index_suffix ) {
      my $index_file = file($self->symlink_path, $mapping_dir, "$file.$index_suffix");

      if ( -f file($self->storage_path, $mapping_dir, "$file.$index_suffix") ) {
        $self->_add_file($index_file);
        $self->_verbose_file_info->{$index_file} = [
          $lane_reference,          # name of the reference
          $lane_mapper,             # name of the mapper
          $mapstats_row->changed,   # last update timestamp
        ];
      }
      # NOTE no warning for missing index files; the assumption is that if the
      # VCF is missing, it's okay that the index is missing
    }
  }
}

#-------------------------------------------------------------------------------

1;

