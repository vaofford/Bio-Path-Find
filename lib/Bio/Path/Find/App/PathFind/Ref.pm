
package Bio::Path::Find::App::PathFind::Ref;

# ABSTRACT: Find reference genones

use v5.10; # for "say"

use MooseX::App::Command;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Term::ReadLine;
use IO::Interactive qw( is_interactive );
use Path::Class;
use File::Find::Rule;
use Archive::Tar;
use Try::Tiny;
use Carp qw( carp );

use Types::Standard qw(
  ArrayRef
  Str
  +Bool
);

use Bio::Path::Find::Types qw( :types );

use Bio::Path::Find::RefFinder;

extends 'Bio::Path::Find::App::PathFind';

with 'Bio::Path::Find::App::Role::Archivist',
     'Bio::Path::Find::App::Role::Linker';

#-------------------------------------------------------------------------------
#- usage text ------------------------------------------------------------------
#-------------------------------------------------------------------------------

# this is used when the "pf" app class builds the list of available commands
command_short_description 'Find reference genomes';

# the module POD is used when the users runs "pf man ref"

=head1 NAME

pf ref - Find reference genomes

=head1 USAGE

  pf ref --id <genome name>

=head1 DESCRIPTION

This command finds reference genomes. Given the name of a reference genome, the
command looks in the index of available references and returns the path to a
directory containing various files for the specified genome.

If an exact match to the genome name is not found, the command returns a
list of any genomes that are an approximate match to the specified name. You
can choose the best match from the list and the command will show the path to
the directory for that genome.

Use "pf man" or "pf man ref" to see more information.

=head1 EXAMPLES

  # get the path to reference genome directory using an exact name
  pf ref -i Yersinia_pestis_CO92_v1

  # get the path to the sequence file for a reference genome
  pf ref -i Yersinia_pestis_CO92_v1 -f fa

  # find a reference using an approximate name
  pf ref -i yersinia_pestis

  # you can use spaces in names instead of underscores; quote the name
  pf ref -i 'yersinia pestis'

  # find approximate matches for a name
  pf ref -i yersinia

  # also handles minor spelling mistakes
  pf ref -i yersina    # missing an "i"

=head1 OPTIONS

These are the options that are available in C<pf ref>. Run C<pf man> to see
information about the options that are common to all C<pf> commands. B<Note>
that unlike other C<pf> commands, C<ref> does not require you to specify type
(using C<--type> or C<-t>); the command can only search for reference genomes
using species name.

=over

=item --filetype, -f <filetype>

Return the path to the sequence (fasta or EMBL) or annotation (GFF) files.
Must be one of C<fa>, C<embl>, or C<gff>.

=item --symlink, -l [<symlink path>]

Create a symlink to the directory containing files for the specified reference
genome. Creates a link by default in the working directory, named according to
the genome in question, or with the specified name, if given.

=item --archive, -a [<tar filename>]

Create a tar archive containing all files for the specified genome. Save to
specified filename, if given.

=item --no-tar-compression, -u

Don't compress tar archives.

=item --zip, -z [<zip filename>]

Create a zip archive containing all files for the specified genome. Save to
specified filename, if given.

=back

=head1 SCENARIOS

=head2 Find a reference genome using an exact name

If you know the exact name of a reference genome, you can get the path to
the directory immediately:

  % pf ref -i Yersinia_pestis_CO92_v1
  /scratch/pathogen/refs/Yersinia/pestis_CO92

You can also be less specific, omitting version numbers, for example:

  % pf ref -i Yersinia_pestis
  /scratch/pathogen/refs/Yersinia/pestis_CO92

You can also use spaces instead of underscores in the name, but you will
need to put the name in quotes, to avoid it being misinterpreted:

  % pf ref -i 'Yersinia pestis'
  /scratch/pathogen/refs/Yersinia/pestis_CO92

Finally, searches are case insensitive:

  % pf ref -i 'yersinia pestis'
  /scratch/pathogen/refs/Yersinia/pestis_CO92

=head2 Find reference genomes matching an approximate name

If you don't know the exact name or version of a reference genome, you can
search for references matching an approximate name:

  % pf ref -i yersinia
  No exact match for "yersinia". Did you mean:
   [1] Yersinia_enterocolitica_subsp_enterocolitica_8081_v1
   [2] Yersinia_pestis_CO92_v1

  Which reference?

The "fuzzy" matching also handles minor spelling mistakes:

  % pf ref -i yersina
  No exact match for "yersina". Did you mean:
   [1] Yersinia_enterocolitica_subsp_enterocolitica_8081_v1
   [2] Yersinia_pestis_CO92_v1

  Which reference?

To get the directory path for one of the available choices, enter the number
for the reference:

  % pf ref -i yersinia
  No exact match for "yersinia". Did you mean:
   [1] Yersinia_enterocolitica_subsp_enterocolitica_8081_v1
   [2] Yersinia_pestis_CO92_v1

  Which reference? 2
  /scratch/pathogen/refs/Yersinia/pestis_CO92

=head2 Archiving data

The C<pf ref> command can create a tar or zip archive containing all of the
files for a given reference genome:

  % pf ref -i yersinia_pestis -a
  Archiving data to 'Yersinia_pestis_CO92.tar.gz'
  Building tar file... done
  /scratch/pathogen/refs/Yersinia/pestis_CO92/Yersinia_pestis_CO92_v1.fa.gen_aux.o
  /scratch/pathogen/refs/Yersinia/pestis_CO92/Yersinia_pestis_CO92_AL590842_v1.embl
  ...

You can create a tar file or a zip archive:

  % pf ref -i yersinia_pestis -z
  Archiving data to 'Yersinia_pestis_CO92.zip'
  Writing zip file... done
  /scratch/pathogen/refs/Yersinia/pestis_CO93/Yersinia_pestis_CO92_v1.fa.gen_aux.o
  /scratch/pathogen/refs/Yersinia/pestis_CO92/Yersinia_pestis_CO92_AL590842_v1.embl
  ...

=head2 Creating symlinks

The C<pf ref> command can create symlinks to the reference genome directory or
files:

  % pf ref -i yersinia_pestis -l
  Creating link as 'Yersinia_pestis_C092'

  % pf ref -i yersinia_pestis -l -f fa
  Creating link as 'Yersinia_pestis_C092_v1.fa'

You can also create links with specific names:

  % pf ref -i yersinia_pestis -l yersinia_ref
  Creating link as 'yersinia_ref'

=cut

#-------------------------------------------------------------------------------
#- command line options --------------------------------------------------------
#-------------------------------------------------------------------------------

# we don't actually need the "--type" option for reffind, since all we're ever
# going to be looking for is species names. Specify a default value.

option '+type' => (
  default => 'species',
);

option 'filetype' => (
  documentation => 'type of files to find',
  is            => 'ro',
  isa           => RefType,
  cmd_aliases   => 'f',
);

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# a RefFinder object

has '_rf' => (
  is      => 'ro',
  isa     => BioPathFindRefFinder,
  lazy    => 1,
  builder => '_build_rf',
);

sub _build_rf {
  return Bio::Path::Find::RefFinder->new;
}

#---------------------------------------

# a slot to store the Path::Class object that represents the path that's
# currently in use. Set by the "run" method and used in the builders that
# set up the output filenames

has '_path' => (
  is  => 'rw',
  isa => Str|PathClassEntity,
);

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

sub run {
  my $self = shift;

  # given a list of search names, find the reference genome names
  my $refs = $self->_rf->find_refs($self->_ids->[0]);

  my $paths;
  if ( scalar @$refs == 1 ) {
    # only one matching reference
    $paths = $self->_rf->lookup_paths($refs, $self->filetype);
  }
  elsif ( scalar @$refs > 1 ) {
    # found multiple matches. If we're running interactively, ask the user
    # which one they meant. Otherwise, just print them
    if ( is_interactive ) {
      $paths = $self->_get_path_interactively($refs);
      unless ( defined $paths ) {
        say 'No reference chosen.';
        return;
      }
    }
    else {
      # non-interactive. Print the list of matching references and bail
      say q(No exact match for ") . $self->_ids->[0] . q(". Possible matches);
      say $_ for @$refs;
      return;
    }
  }
  else {
    say 'No matching reference genomes found. Try a less specific species name.';
    return;
  }

  # by this point, we have only a single matching reference genome, and we
  # know the path to its directory
  $self->_path($paths->[0]);

  # do something with the found paths
  if ( $self->_symlink_flag or
       $self->_tar_flag or
       $self->_zip_flag ) {
    $self->_make_tar($self->_path)      if $self->_tar_flag;
    $self->_make_zip($self->_path)      if $self->_zip_flag;
    $self->_make_symlinks($self->_path) if $self->_symlink_flag;
  }
  else {
    say $self->_path;
  }
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# overwrite the builders that set the names of the tar and zip files for the
# Archivist Role

sub _build_tar_filename {
  my $self = shift;

  my $tar_file_name = $self->_get_dir_name . '.tar';
  $tar_file_name .= '.gz' unless $self->no_tar_compression;

  return file($tar_file_name);
}

#---------------------------------------

sub _build_zip_filename {
  my $self = shift;

  return file($self->_get_dir_name . '.zip');
}

#---------------------------------------

sub _build_symlink_dest {
  my $self = shift;

  my $dest = dir( 'pf_' . $self->_renamed_id );

  if ( defined $self->_path ) {
    if ( $self->_path->isa('Path::Class::File') ) {
      $dest = file $self->_path->basename;
    }
    else {
      $dest = dir $self->_get_dir_name;
    }
  }

  return $dest;
}

#-------------------------------------------------------------------------------

# build a stub for a destination filename from the path to the reference
# genome directory. Convert a filename like
#
#     /lustre/scratch108/pathogen/pathpipe/refs/Yersinia/pestis_CO92
#
# to an output like
#
#     Yersinia_pestis_C092

sub _get_dir_name {
  my $self = shift;

  # get the location of the directory containing the references
  my $refs_root = dir( $self->config->{refs_root} );

  # count the number of directories in the path to that dir
  my $length_root_path = $refs_root->dir_list;

  # get the components of the output path, but starting from the root directory
  my @dest_path = $self->_path->isa('Path::Class::File')
                ? $self->_path->parent->dir_list($length_root_path)
                : $self->_path->dir_list($length_root_path);

  # join the remaining directories
  return join '_', @dest_path;
}

#-------------------------------------------------------------------------------

# overwrite two methods that are used by "_make_tar" and "_make_zip" from the
# Archivist Role for gathering filenames and renaming them in the archives.

sub _collect_filenames {
  my ( $self, $path ) = @_;

  # find the files under the specified path. If the path is a file path, we
  # should still end up with that single file in the array
  my @files = File::Find::Rule->file->in($path);

  # convert the strings into Path::Class::File objects
  my @file_objects = map { file $_ } @files;

  return \@file_objects;
}

#---------------------------------------

sub _rename_file {
  my ( $self, $old_filename ) = @_;

  my $refs_root = dir( $self->config->{refs_root} )->stringify;

  # trim the root path off the new filename, so that we're left with a
  # path starting with the two directories that are named for the genus
  # and species of the reference genome
  ( my $new_filename = $old_filename ) =~ s|$refs_root/||;

  # filenames in an archive are specified as Unix paths (see
  # https://metacpan.org/pod/Archive::Tar#tar-rename-file-new_name)
  $old_filename = file( $old_filename )->as_foreign('Unix');
  $new_filename = file( $new_filename )->as_foreign('Unix');

  $self->log->debug( "renaming |$old_filename| to |$new_filename|" );

  return $new_filename;
}

#-------------------------------------------------------------------------------

# make symlinks for the specified path. That can be a directory or a file

sub _make_symlinks {
  my ( $self, $path ) = @_;

  my $dest = $self->_symlink_dest;

  say STDERR "Creating link as '$dest'";

  my $success = 0;
  try {
    $success = symlink( $path, $dest );
  }
  catch {
    # this should only happen if perl can't create symlinks on the current
    # platform
    Bio::Path::Find::Exception->throw( msg => "ERROR: cannot create symlinks: $_" );
  };

  carp qq(WARNING: failed to create symlink for "$path" at "$dest")
    unless $success;
}

#-------------------------------------------------------------------------------

# print out the possible references, each with an index, and get the user to
# pick one

sub _get_path_interactively {
  my ( $self, $refs ) = @_;

  say q(No exact match for ") . $self->_ids->[0] . q(". Did you mean:);

  # list the possible choices, adding an index to identify them
  for ( my $i = 1; $i <= scalar @$refs; $i++ ) {
    printf "%s[%d] %s\n", ( $i < 10 ? ' ' : '' ), $i, $refs->[$i - 1];
  }

  # ask the user which one they want
  my $term = Term::ReadLine->new('ref');
  my $chosen = $term->readline('Which reference? ');

  # return immediately if there's no value
  return unless $chosen;

  # make sure we got a valid index number
  unless ( $chosen =~ m/^\d+$/
           and $chosen >= 1 and $chosen <=( scalar @$refs + 1 )
           and defined $refs->[$chosen - 1] ) {
    return;
  }

  # convert the genome name to a path and print them
  my $paths = $self->_rf->lookup_paths( [ $refs->[$chosen -1] ], $self->filetype );

  return $paths;
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

