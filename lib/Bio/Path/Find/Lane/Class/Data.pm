
package Bio::Path::Find::Lane::Class::Data;

# ABSTRACT: a class that adds pathfind-specific functionality to the B::P::F::Lane class

use Moose;
use Path::Class;
use Carp qw( carp );
use File::Basename;

use Types::Standard qw( Maybe );

use Bio::Path::Find::Types qw( :types );

extends 'Bio::Path::Find::Lane';

with 'Bio::Path::Find::Lane::Role::Stats';

=head1 DESCRIPTION

This class adds functionality to L<Lanes|Bio::Path::Find::Lane>, allowing them
to find statistics and files for sequencing data. This class provides the
following methods for finding files:

=over

=item _get_fastq

=item _get_corrected

=back

both of which are used for C<pathfind>-like searching for files.

It also provides a mapping between filetype and file extension, via
the L<_build_filetype_extensions> builder. The mapping is:

  fastq     => '.fastq.gz',
  bam       => '*.bam',
  pacbio    => '*.h5',
  corrected => '*.corrected.*',

Finally, the class provides builders for attributes that generate stats about
sequencing lanes:

=over

=item _build_stats_header

=item _build_stats

=back

again, both of which are used to generate stats as provided by C<pathfind>.

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

# make the "filetype" attribute require values of type DataType. This is to
# make sure that this class correctly restrict the sorts of files that it will
# return.

has '+filetype' => (
  isa => Maybe[DataType],
);

#---------------------------------------

# when we generate statistics, we want to use the QC mapping, as opposed to any
# other mappings that might have been run on the lane.
#
# This value is defined on the Lane::Role::Stats role and used in there to
# determine whether to return statistics for mappings that are associated with
# QC or other mappings.

has '+use_qc_stats' => (
  default => 1,
);

#-------------------------------------------------------------------------------
#- builders --------------------------------------------------------------------
#-------------------------------------------------------------------------------

# build an array of headers for the statistics display
#
# required by the Stats Role

sub _build_stats_headers {
  my $self = shift;

  return [
    'Study ID',
    'Sample',
    'Lane Name',
    'Cycles',
    'Reads',
    'Bases',
    'Map Type',
    'Reference',
    'Reference Size',
    'Mapper',
    'Mapstats ID',
    'Mapped %',
    'Paired %',
    'Mean Insert Size',
    'Depth of Coverage',
    'Depth of Coverage sd',
    'Adapter %',
    'Transposon %',
    'Genome Covered',
    'Duplication Rate',
    'Error Rate',
    'NPG QC',
    'Manual QC',
    'No. Het SNPs',
    '% Het SNPs (Total Genome)',
    '% Het SNPs (Genome Covered)',
    '% Het SNPs (Total No. of SNPs)',
    'QC Pipeline',
    'Mapping Pipeline',
    'Archiving Pipeline',
    'SNP Calling Pipeline',
    'RNASeq Pipeline',
    'Assembly Pipeline',
    'Annotation Pipeline',
  ];
}

#-------------------------------------------------------------------------------

# collect together the fields for the statistics display
#
# required by the Stats Role

sub _build_stats {
  my $self = shift;

  # for each mapstats row for this lane, get a row of statistics, as an
  # arrayref, and push it into the return array.
  my @stats = map { $self->_get_stats_row($_) } $self->_all_mapstats_rows;

  return \@stats;
}

#-------------------------------------------------------------------------------

# get a row of statistics for this lane. If a row from the mapstats table is
# supplied, we use that for determining values that rely on the mapstats
# values, otherwise leave the field as undef

sub _get_stats_row {
  my ( $self, $ms ) = @_;

  # shortcut to a hash containing Bio::Track::Schema::Result objects
  my $t = $self->_tables;

  return [
    $t->{project}->ssid,
    $t->{sample}->name,
    $self->row->name,
    $self->row->readlen,
    $self->row->raw_reads,
    $self->row->raw_bases,
    $self->_map_type($ms),
    defined $ms ? $ms->assembly->name           : undef,
    defined $ms ? $ms->assembly->reference_size : undef,
    defined $ms ? $ms->mapper->name             : undef,
    defined $ms ? $ms->mapstats_id              : undef,
    $self->_mapping_is_complete($ms)
      ? $self->_percentage( $ms->reads_mapped, $ms->raw_reads )
      : '0.0',
    $self->_mapping_is_complete($ms)
      ? $self->_percentage( $ms->reads_paired, $ms->raw_reads )
      : '0.0',
    defined $ms ? $ms->mean_insert : undef,
    $self->_depth_of_coverage($ms),
    $self->_depth_of_coverage_sd($ms),
    $self->_adapter_percentage($ms),
    $self->_transposon_percentage($ms),
    $self->_genome_covered($ms),
    $self->_duplication_rate($ms),
    $self->_error_rate($ms),
    $self->row->npg_qc_status,
    $self->row->qc_status,
    $self->_het_snp_stats, # returns 4 values
    $self->pipeline_status('qc'),
    $self->pipeline_status('mapped'),
    $self->pipeline_status('stored'),
    $self->pipeline_status('snp_called'),
    $self->pipeline_status('rna_seq_expression'),
    $self->pipeline_status('assembled'),
    $self->pipeline_status('annotated'),
  ];
}

#-------------------------------------------------------------------------------

# build mapping between filetype and file extension. The mapping is specific
# to data files related to lanes, such as fastq or bam.

sub _build_filetype_extensions {
  {
    fastq     => '.fastq.gz',
    bam       => '*.bam', # NOTE no wildcard in mapping in original PathFind
    pacbio    => '*.h5',
    corrected => '*.corrected.*',
  };
}

# NOTE if there is a "_get_*" method for one of the keys, then calling
# NOTE $lane->find_files(filetype=>'<key>') will call that method to find files.
# NOTE If there's no corresponding "_get_*" method, "find_files" will fall back
# NOTE on calling "_get_files_by_extension", which will use Find::File::Rule to
# NOTE look for files according to the pattern given in the hash value.

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

sub _get_fastq {
  my $self = shift;

  $self->log->trace('looking for fastq files');

  # we have to save a reference to the "latest_files" relationship for each
  # lane before iterating over it, otherwise DBIC will continually return the
  # first row of the ResultSet
  # (see https://metacpan.org/pod/DBIx::Class::ResultSet#next)
  my $files = $self->row->latest_files;

  FILE: while ( my $file = $files->next ) {
    my $filename = $file->name;

    # for illumina, the database stores the names of the fastq files directly.
    # For pacbio, however, the database stores the names of the bas files or BAM files. Work
    # out the names of the fastq files from those filenames
    if($self->row->database->name =~ m/pacbio/)
	{
		next FILE if( $filename =~ m/bax\.h5/ || $filename =~ m/scraps\.bam$/);
		my($basefilename, $dirs, $suffix) = fileparse($filename, (qr/bas\.h5$/, qr/subreads\.bam$/));
		$filename = $basefilename.'fastq.gz';
	}

    my $filepath = file( $self->symlink_path, $filename );

    if ( $filepath =~ m/fastq/ and
         $filepath !~ m/pool_1\.fastq\.gz/ ) {

      # the filename here is obtained from the database, so the file really
      # should exist on disk. If it doesn't exist, if the symlink in the root
      # directory tree is broken, we'll show a warning, because that indicates
      # a fairly serious mismatch between the two halves of the tracking system
      # (database and filesystem)
      unless ( -e $filepath ) {
        carp "ERROR: database says that '$filepath' should exist but it doesn't";
        next FILE;
      }

      $self->_add_file($filepath);
    }
  }
}

#-------------------------------------------------------------------------------

sub _get_corrected {
  my $self = shift;

  $self->log->trace('looking for "corrected" files');

  my $filename = $self->row->hierarchy_name . '.corrected.fasta.gz';
  my $filepath = file( $self->symlink_path, $filename );

  $self->_add_file($filepath) if -e $filepath;
}

#-------------------------------------------------------------------------------

1;

