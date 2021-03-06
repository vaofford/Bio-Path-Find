
package Bio::Path::Find::App::PathFind::RNASeq;

# ABSTRACT: Find RNA-Seq results

use v5.10; # for "say"

use MooseX::App::Command;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Carp qw ( carp );
use Path::Class;
use Try::Tiny;
use DateTime;

use Types::Standard qw(
  ArrayRef
  Str
  +Bool
);

use Bio::Path::Find::Types qw( :types MappersFromMapper );

use Bio::Path::Find::Exception;
use Bio::Path::Find::Lane::Class::RNASeq;

extends 'Bio::Path::Find::App::PathFind';


with 'Bio::Path::Find::App::Role::Archivist',
     'Bio::Path::Find::App::Role::Linker',
     'Bio::Path::Find::App::Role::Statistician',
     'Bio::Path::Find::App::Role::RNASeqSummariser',
     'Bio::Path::Find::App::Role::UsesMappings';

#-------------------------------------------------------------------------------
#- usage text ------------------------------------------------------------------
#-------------------------------------------------------------------------------

# this is used when the "pf" app class builds the list of available commands
command_short_description 'Find RNA-Seq results';

# the module POD is used when the users runs "pf man rnaseq"

=head1 NAME

pf rnaseq - Find RNA-Seq results

=head1 USAGE

  pf rnaseq --id <id> --type <ID type> [options]

=head1 DESCRIPTION

This pathfind command will return information about RNA-Seq results.  Specify
the type of data using C<--type> and give the accession, name or identifier for
the data using C<--id>.

Use "pf man" or "pf man rnaseq" to see more information.

=head1 EXAMPLES

  # find CSV files with read statistics for a set of lanes
  pf rnaseq -t lane -i 12345_1

  # find BAM files for a study
  pf rnaseq -t study -i 123 -f bam

  # get a set of tab files to go into Artemis
  pf rnaseq -t lane -i 12345_1 -M smalt -f coverage

  # find coverage plots for lanes that were mapped using a specific mapper
  pf rnaseq -t lane -i 12345_1 -M smalt -f coverage

  # get statistics for lanes mapped against a specific reference
  pf rnaseq -t lane -i 12345_1 -R Streptococcus_suis_P1_7_v1 -s

  # get summary of lane metadata and corresponding count filenames
  pf rnaseq -t lane -i 12345_1 -S

=cut

=head1 OPTIONS

These are the options that are specific to C<pf rnaseq>. Run C<pf rnaseq> to
see information about the options that are common to all C<pf> commands.

=over

=item --filetype, -f <file type>

Show only files of the specified type. Must be one of the following types:
C<bam>, C<coverage>, C<featurecounts>, C<spreadsheet> (default), or C<tab>.

=item --qc, -q <status>

Only show files from lanes with the specified QC status. Must be either
C<passed>, C<failed>, or C<pending>.

=item --details, -d

Show the details of each mapping.

=item --mapper, -M <mapper>

Only show files that were generated using the specified mapper(s). You can
specify multiple mappers by providing a comma-separated list. The name of the
mapper must be one of: C<bowtie2>, C<bwa>, C<bwa_aln>, C<smalt>, C<ssaha2>,
C<stampy>, C<tophat>.

=item --reference, -R <reference genome>

Only show files generated by mapping against a specific reference genome. The
name of the genome must be exact; use C<pf ref -R> to find the name of a
reference.

=item --stats, -s [<stats filename>]

Write a file with statistics for the found lanes. Save to specified filename,
if given.

=item --summary, -S [<summary filename>]
Write a file with metadata and file paths for the found lanes. If a filename 
is given, the summary will be writen to that file.

=item --symlink, -l [<symlink directory>]

Create symlinks to found data. Create links in the specified directory, if
given, or in the current working directory.

=item --archive, -a [<tar filename>}

Create a tar archive containing the found files. Save to the specified
filename, if given

=item --no-tar-compression, -u

Don't compress tar archives.

=item --zip, -z [<zip filename>]

Create a zip archive containing data files for found lanes. Save to
specified filename, if given.

=item --rename, -r

Rename filenames when creating archives or symlinks, replacing hashed
(#) with underscores (_).

=back

=head1 SCENARIOS

=head2 Find CSV files RPKM and read counts

The default behaviour of the C<pf rnaseq> command is to return the paths for
CSV files with RPKM and read counts for each CDS/polypeptide:

  pf rnaseq -t lane -i 12345_1#1
  /scratch/pathogen/prokaryotes/seq-pipelines/Escherichia/coli/TRACKING/3893STDY6199423/SLX/15100687/12345_1#1/593103.pe.markdup.bam.expression.csv

There are five types of file available for each lane with RNA-Seq data:

=over

=item bam

BAM file with reads corrected according to the protocol

=item coverage

coverage plots, suitable for Artemis, for each sequence

=item featurecounts

CSV file giving reads per gene model from FeatureCounts (Mouse and Human)

=item spreadsheet

CSV file with RPKM and read counts for each CDS/polypeptide

=item tab

tab files, suitable for Artemis, for each sequence, with intergenic regions marked up

=back

You can also see a few more details about each mapping, using the C<--details>
(C<-d>) option:

  pf rnaseq -t lane -i 12345_1#1 -d
  /scratch/pathogen/prokaryotes/seq-pipelines/Escherichia/coli/TRACKING/3893STDY6199423/SLX/15100687/12345_1#1/593103.pe.markdup.bam.expression.csv    Escherichia_coli_ST131_strain_EC958_v1  smalt   2016-03-19T14:52:19

The output now includes four tab-separated columns for each file, giving:

=over

=item full file path

=item reference genome that was used during mapping

=item name of the mapping software used

=item creation date of the mapping

=back

=head2 Show files from mappings generated by a specific mapper

You can filter the list of returned files in a couple of ways. Some lanes will
be mapped multiple times using different mappers, so you can specify which
mapping program you need using the C<--mapper> (C<-M>) option:

  pf rnaseq -t lane -i 12345_1 -M bwa

You will now see only files derived from mappings generated using C<bwa>. If
you want to see information for mappings generated by more than one mapper, you
can use a comma-separated list of mappers:

  pf rnaseq -t lane -i 12345_1 -M bwa,smalt

or you can use the C<-M> option multiple times:

  pf rnaseq -t lane -i 12345_1 -M bwa -M smalt

=head2 Show files from mappings that use a specific reference genome

You can also filter files according to which reference genome a lane was mapped
against, using C<--reference> (C<-R>):

  pf rnaseq -t lane -i 12345_1 -R Escherichia_coli_NA114_v2

You can only specify one reference at a time.

The name of the reference must be given exactly. You can find the full, exact
name for a reference using C<pf ref>:

  % pf ref -i Eschericia_coli -R
  Escherichia_coli_0127_H6_E2348_69_v1
  Escherichia_coli_042_v1
  Escherichia_coli_9000_v0.1
  ...

=head2 Write a summary TSV file

You can generate a single summary file which contains the lane metadata and the 
corresponding expression pipeline filename using C<--summary> (abbreviated to C<-S>):

pf rnaseq -t lane -i 12345_1 -S

If the file type has been set, the corresponding file names will be used:

pf rnaseq -t lane -i 12345_1 -f featurecounts -S

=head2 Archive or link the found files

You can generate a tar file or a zip file containing all of the files that are
found:

  pf rnaseq -t lane -i 12345_1 -a csvs.tar.gz

or

  pf rnaseq -t lane -i 12345_1 -z csvs.zip

If the files that you're archiving are already gzip compressed, e.g. coverage
plots, there's not much to be gained from compressing them again when
archiving. If you're creating a tar archive, you can use the
C<--no-tar-compression> (C<-N>) option to skip the compression. The resulting
tar file will not be any larger but it will be quicker to generate:

  pf rnaseq -t lane -i 12345_1 -f coverage -a plots.tar -N

Alternatively, you can create symlinks to the files in a directory of your
choice:

  pf rnaseq -t lane -i 12345_1 -l bam_files -f bam

=head1 SEE ALSO

=over

=item pf map - find information about mappings

=item pf assembly - find genome assemblies

=item pf status - find pipeline status for lanes

=back

=cut

#-------------------------------------------------------------------------------
#- command line options --------------------------------------------------------
#-------------------------------------------------------------------------------

option 'filetype' => (
  documentation => 'type of files to find',
  is            => 'ro',
  isa           => RNASeqType,
  cmd_aliases   => 'f',
  default       => 'spreadsheet',
);

option 'qc' => (
  documentation => 'filter results by lane QC state',
  is            => 'ro',
  isa           => QCState,
  cmd_aliases   => 'q',
);

#-------------------------------------------------------------------------------
#- builders --------------------------------------------------------------------
#-------------------------------------------------------------------------------

# this is a builder for the "_lane_class" attribute, which is defined on the
# parent class, B::P::F::A::PathFind. The return value specifies the class of
# object that should be returned by the B::P::F::Finder::find_lanes method.

sub _build_lane_class {
  return 'Bio::Path::Find::Lane::Class::RNASeq';
}

#---------------------------------------

# change the name of the tar, zip and stats files

sub _build_tar_filename { file $_[0]->_renamed_id . '.rnaseqfind' . ( $_[0]->no_tar_compression ? '.tar' : '.tar.gz' ) }
sub _build_zip_filename { file shift->_renamed_id . '.rnaseqfind.zip' }
sub _build_stats_file   { file shift->_renamed_id . '.rnaseqfind_stats.csv' }

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

sub run {
  my $self = shift;

  # some quick checks that will allow us to fail fast if things aren't going to
  # let the command run to successfully

  if ( $self->_symlink_flag and           # flag is set; we're making symlinks.
       $self->_symlink_dest and           # destination is specified.
       -e $self->_symlink_dest and        # the destintation path exists.
       not -d $self->_symlink_dest ) {    # but it's not a directory.
    Bio::Path::Find::Exception->throw(
      msg => 'ERROR: symlink destination "' . $self->_symlink_dest
             . q(" exists but isn't a directory)
    );
  }

  if ( not $self->force ) {
    if ( $self->_tar_flag and       # flag is set; we're writing stats.
         $self->_tar and            # destination file is specified.
         -e $self->_tar ) {         # output file already exists.
      Bio::Path::Find::Exception->throw(
        msg => 'ERROR: tar archive "' . $self->_tar . '" already exists; not overwriting. Use "-F" to force overwriting'
      );
    }

    if ( $self->_zip_flag and $self->_zip and -e $self->_zip ) {
      Bio::Path::Find::Exception->throw(
        msg => 'ERROR: zip archive "' . $self->_zip . '" already exists; not overwriting. Use "-F" to force overwriting'
      );
    }

    if ( $self->_stats_flag and $self->_stats_file and -e $self->_stats_file ) {
      Bio::Path::Find::Exception->throw(
        msg => 'ERROR: stats file "' . $self->_stats_file . '" already exists; not overwriting. Use "-F" to force overwriting'
      );
    }

    if ( $self->_summary_flag and -f $self->_summary_file and not $self->force ) {
      Bio::Path::Find::Exception->throw(
        msg => q(ERROR: TSV file ") . $self->_summary_file . q(" already exists; not overwriting existing file)
      );
    }
  }

  #---------------------------------------

  # build the parameters for the finder
  my %finder_params = (
    ids      => $self->_ids,
    type     => $self->_type,
    filetype => $self->filetype, # default to finding spreadsheets
  );

  #---------------------------------------

  # these are filters that are applied by the finder

  # when finding lanes, should the finder filter on QC status ?
  $finder_params{qc} = $self->qc if $self->qc;

  # should we look for lanes with the "rnaseq" bit set on the "processed" bit
  # field ? Turning this off, i.e. setting the command line option
  # "--ignore-processed-flag", will allow the command to return data for lanes
  # that haven't completed the RNA-Seq pipeline.
  $finder_params{processed} = Bio::Path::Find::Types::RNA_SEQ_EXPRESSION_PIPELINE
    unless $self->ignore_processed_flag;

  #---------------------------------------

  # these are filters that are applied by the lanes themselves, when they're
  # finding files to return

  # when finding files, should the lane restrict the results to files created
  # with a specified mapper ?
  $finder_params{lane_attributes}->{mappers} = $self->mapper
    if $self->mapper;

  # when finding files, should the lane restrict the results to mappings
  # against a specific reference ?
  $finder_params{lane_attributes}->{reference} = $self->reference
    if $self->reference;

  #---------------------------------------

  # find lanes
  my $lanes = $self->_finder->find_lanes(%finder_params);

  if ( scalar @$lanes < 1 ) {
    say STDERR 'No data found.';
    return;
  }

  if ( $self->_symlink_flag or
       $self->_tar_flag or
       $self->_zip_flag or
       $self->_stats_flag or
       $self->_summary_flag ) {
    # can make symlinks, tarball or zip archive all in the same run
    $self->_make_symlinks($lanes) if $self->_symlink_flag;
    $self->_make_tar($lanes)      if $self->_tar_flag;
    $self->_make_zip($lanes)      if $self->_zip_flag;
    $self->_make_stats($lanes)    if $self->_stats_flag;
    $self->_make_summary($lanes)  if $self->_summary_flag;
  }
  else {
    # print the list of files. Should we show extra info ?
    if ( $self->details ) {
      # yes; print file path, reference, mapper and timestamp
      $_->print_details for @$lanes;
    }
    else {
      # no; just print the paths
      $_->print_paths for @$lanes;
    }
  }
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

