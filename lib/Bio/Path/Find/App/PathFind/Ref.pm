
package Bio::Path::Find::App::PathFind::Ref;

# ABSTRACT: Find reference genones

use v5.10; # for "say"

use MooseX::App::Command;
use namespace::autoclean;
use MooseX::StrictConstructor;

use Term::ReadLine;
use IO::Interactive qw( is_interactive );
use Path::Class;
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

This command finds reference genomes. Given either an exact or an approximate
name of a reference genome, the command looks in the index of available
references and returns the path to a directory containing various files for the
specified genome.

If an exact match to the genome name is not found, the command returns an
interactive list of any genomes that are an approximate match to the specified
name. You can choose the best match from the list and the command will show the
path to the directory for that genome.

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

=item --reference-names, -R

Show the names of matching reference genomes, rather than paths to their files
on disk.

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

=item --all, -A

If your search returns multiple matches, by default you will be presented with
a list of all matching reference genomes, from which you can choose to show
paths for one or all matches. If you want to return all matching references by
default, without being asked interactively, adding C<--all> will bypass the
interactive selection and select all references automatically.

=back

=head1 SCENARIOS

=head2 Find a reference genome using an exact name

If you know the exact name of a reference genome, you can get the path to
the sequence file immediately:

  % pf ref -i Yersinia_pestis_CO92_v1
  /scratch/pathogen/refs/Yersinia/pestis_CO92/Yersinia_pestis_CO92_v1.fa

You can also be less specific, omitting version numbers, for example:

  % pf ref -i Yersinia_pestis
  /scratch/pathogen/refs/Yersinia/pestis_CO92/Yersinia_pestis_CO92_v1.fa

You can also use spaces instead of underscores in the name, but you will need
to put the name in quotes, to avoid it being misinterpreted by the shell:

  % pf ref -i 'Yersinia pestis'
  /scratch/pathogen/refs/Yersinia/pestis_CO92/Yersinia_pestis_CO92_v1.fa

Finally, note that searches are case INsensitive:

  % pf ref -i 'yersinia pestis'
  /scratch/pathogen/refs/Yersinia/pestis_CO92/Yersinia_pestis_CO92_v1.fa

=head2 Find reference genomes matching an approximate name

If you don't know the exact name or version of a reference genome, you can
search for references matching an approximate name:

  % pf ref -i yersinia
  No exact match for "yersinia". Did you mean:
   [1] Yersinia_enterocolitica_subsp_enterocolitica_8081_v1
   [2] Yersinia_pestis_CO92_v1
   [a] all references

  Which reference?

To get the directory path for one of the available choices, enter the number
for the reference:

  % pf ref -i yersinia
  No exact match for "yersinia". Did you mean:
   [1] Yersinia_enterocolitica_subsp_enterocolitica_8081_v1
   [2] Yersinia_pestis_CO92_v1
   [a] all references

  Which reference? 2
  /scratch/pathogen/refs/Yersinia/pestis_CO92/Yersinia_pestis_CO92_v1.fa

To get the directory paths for all matching references, enter C<a>:

  % pf ref -i yersinia
  No exact match for "yersinia". Did you mean:
   [1] Yersinia_enterocolitica_subsp_enterocolitica_8081_v1
   [2] Yersinia_pestis_CO92_v1
   [a] all references

  Which reference? a
  /scratch/pathogen/refs/Yersinia/enterocolitica_subsp_enterocolitica_8081/Y...
  /scratch/pathogen/refs/Yersinia/pestis_CO92/Yersinia_pestis_CO92_v1.fa

You can bypass the interactive selection and automatically return all
matching references by adding the C<--all> option:

  % pf ref -i yersinia -A
  /scratch/pathogen/refs/Yersinia/enterocolitica_subsp_enterocolitica_8081/Y...
  /scratch/pathogen/refs/Yersinia/pestis_CO92/Yersinia_pestis_CO92_v1.fa

Note that the "fuzzy" matching also handles minor spelling mistakes. Searching
for "yersina", with a missing "i", will return two possible matches:

  % pf ref -i yersina
  No exact match for "yersina". Did you mean:
   [1] Yersinia_enterocolitica_subsp_enterocolitica_8081_v1
   [2] Yersinia_pestis_CO92_v1
   [a] all references

  Which reference?

=head2 Find the name for a reference genome

The default behaviour of the C<pf ref> command is to return paths to reference
genomes matching the supplied name. By adding the C<--reference-names> (C<-R>)
option, you can make the command return the full name of the reference instead.

  % pf ref -i yersinia_pestis -R
  Yersinia_pestis_CO92_v1

If you use a name that finds multiple matching references, you will get the
full names of all of the matches:

  % pf ref -i yersinia -R
  Yersinia_enterocolitica_subsp_enterocolitica_8081_v1
  Yersinia_pestis_CO92_v1

This might be useful if you need to find lanes that have been mapped to a
specific reference, in which case you need to supply the exact name of the
reference genome to C<pf map>.

=head2 Find different file types

By default the C<pf ref> command returns the path to the sequence file for the
reference genome(s). You can also get paths for the GFF or EMBL files for
references, using the C<--filetype> (C<-f>) option:

  % pf ref -i Yersinia_pestis -f embl
  /scratch/pathogen/refs/Yersinia/pestis_CO92/Yersinia_pestis_CO92_v1.embl

  % pf ref -i Yersinia_pestis -f gff
  /scratch/pathogen/refs/Yersinia/pestis_CO92/annotation/Yersinia_pestis_CO92_v1.gff

B<Note> that the GFF file that is returns when you use C<-f gff> is always the
one generated by C<prokka>.

=head2 Archiving data

The C<pf ref> command can create a tar or zip archive containing all of the
files for a given reference genome:

  % pf ref -i yersinia_pestis -a
  Archiving data to 'Yersinia_pestis_CO92.tar.gz'
  Building tar file... done
  /scratch/pathogen/refs/Yersinia/pestis_CO92/Yersinia_pestis_CO92_v1.fa

You can create a tar file or a zip archive:

  % pf ref -i yersinia_pestis -z
  Archiving data to 'Yersinia_pestis_CO92.zip'
  Writing zip file... done
  /scratch/pathogen/refs/Yersinia/pestis_CO92/Yersinia_pestis_CO92_v1.fa

You can also archive different filetypes:

  % pf ref -i yersinia_pestis -a -f gff
  Archiving data to 'Yersinia_pestis_CO92.tar.gz'
  Building tar file... done
  /scratch/pathogen/refs/Yersinia/pestis_CO92/annotation/Yersinia_pestis_CO92_v1.gff

=cut

=head2 Creating symlinks

The C<pf ref> command can create symlinks to files for the reference genome:

  % pf ref -i yersinia_pestis -l
  Creating link from '/scratch/pathogen/refs/Yersinia/pestis_CO92/Yersinia_p...

You can create links to other filetypes too using C<-f>:

  % pf ref -i yersinia_pestis -l -f gff
  Creating link from '/scratch/pathogen/refs/Yersinia/pestis_CO92/annotation...

You can also create links with specific names:

  % pf ref -i yersinia_pestis -l yersinia_reference_sequence.fa
  Creating link from '/scratch/pathogen/refs/Yersinia/pestis_CO92/Yersinia_p...

If your search finds multiple matching reference genomes, C<pf ref> will create
multiple links:

  % pf ref -i yersinia -l
  No exact match for "yersinia". Did you mean:
   [1] Yersinia_enterocolitica_subsp_enterocolitica_8081_v1
   [2] Yersinia_pestis_CO92_v1
   [a] all references

  Which reference? a
  Creating link from '/scratch/pathogen/refs/Yersinia/enterocolitica_subsp_enterocolitica_8081/Y...
  Creating link from '/scratch/pathogen/refs/Yersinia/pestis_CO92/Yersinia_pestis_CO92_v1.fa

If you have multiple reference genomes, if you give a value for C<-l> it will
be treated as a directory name, and C<pf ref> will create the directory (unless
it already exists) and will create soft links in that new directory:

  % pf ref -i yersinia -l my_links -A
  Creating link from '/scratch/patho...' to 'my_links/Yersinia_enterocolitica_subsp_enterocolitica_8081_v1.fa'
  Creating link from '/scratch/patho...' to 'my_links/Yersinia_pestis_CO92_v1.fa'

=cut

#-------------------------------------------------------------------------------
#- command line options --------------------------------------------------------
#-------------------------------------------------------------------------------

# we don't actually need the "--type" option for reffind, since all we're ever
# going to be looking for is species names. Specify a default value.

option '+type' => (
  default => 'species',
);

#---------------------------------------

option 'filetype' => (
  documentation => 'type of files to find',
  is            => 'ro',
  isa           => RefType,
  cmd_aliases   => 'f',
  default       => 'fa',
);

#---------------------------------------

option 'reference_names' => (
  documentation => 'show names of references, not paths',
  is            => 'ro',
  isa           => Bool,
  cmd_aliases   => 'R',
  cmd_flag      => 'reference-names',
);

#---------------------------------------

option 'all' => (
  documentation => q(don't ask me to choose a reference, return all matches),
  is            => 'ro',
  isa           => Bool,
  cmd_aliases   => 'A',
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

# a slot to store the Path::Class objects that represent the paths that are
# currently in use. Set by the "run" method and used in the builders that
# set up the output filenames

has '_paths' => (
  is  => 'rw',
  isa => ArrayRef[PathClassEntity],
);

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

sub run {
  my $self = shift;

  # given a list of search names, find the reference genome names
  my $refs = $self->_rf->find_refs($self->_ids->[0]);

  # if we don't find any matches, we're done here
  if ( not @$refs ) {
    say 'No matching reference genomes found. Try a less specific species name.';
    return;
  }

  # should we simply show the reference genome names ?
  if ( $self->reference_names ) {
    say $_ for @$refs;
    return;
  }

  my $paths;
  # if there's only one matching reference, or the user specified "--all", just
  # keep all paths
  if ( scalar @$refs == 1 or $self->all ) {
    $paths = $self->_rf->lookup_paths( $refs, $self->filetype );
  }
  else {
    # if we're running interactively, ask the user which reference they want,
    # otherwise, just print them
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

  # by this point, we have a list of directories for matching reference genomes
  $self->_paths($paths);

  #---------------------------------------

  # some quick checks that will allow us to fail fast if things aren't going to
  # let the command run to successfully

  # archiving can be slow if there are lots of files, so do a quick check to see
  # that we're not later going to complain about a pre-existing archive file

  if ( not $self->force ) {
    if ( $self->_tar_flag and $self->_tar and -e $self->_tar ) {
      Bio::Path::Find::Exception->throw(
        msg => 'ERROR: output tar file "' . $self->_tar . q(" already exists)
      );
    }
    elsif ( $self->_zip_flag and $self->_zip and -e $self->_zip ) {
      Bio::Path::Find::Exception->throw(
        msg => 'ERROR: output zip file "' . $self->_zip . q(" already exists)
      );
    }
  }

  #---------------------------------------

  # do something with the found paths
  if ( $self->_symlink_flag or
       $self->_tar_flag or
       $self->_zip_flag ) {
    $self->_make_tar($self->_paths)      if $self->_tar_flag;
    $self->_make_zip($self->_paths)      if $self->_zip_flag;
    $self->_make_symlinks($self->_paths) if $self->_symlink_flag;
  }
  else {
    say $_ for @{ $self->_paths };
  }
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# overwrite the builders that set the names of the tar and zip files for the
# Archivist Role

# generate the filename for a tar archive

sub _build_tar_filename {
  my $self = shift;

  # if we have a single reference genome, make the filename reflective of
  # the name of that genome
  if ( defined $self->_paths and scalar @{ $self->_paths } == 1 ) {
    my $dir_name = $self->_get_dir_name || 'reffind';
    my $tar_file_name =  "$dir_name.tar";
    $tar_file_name .= '.gz' unless $self->no_tar_compression;

    return file($tar_file_name);
  }
  # if there are multiple genomes, use the fuzzy name that we were given
  else {
    return file( 'reffind_' . $self->_renamed_id . ( $self->no_tar_compression ? '.tar' : '.tar.gz' ) );
  }
}

#---------------------------------------

# generate the filename for a zip archive

sub _build_zip_filename {
  my $self = shift;

  if ( defined $self->_paths and scalar @{ $self->_paths } == 1 ) {
    my $dir_name = $self->_get_dir_name || 'reffind';
    return file($dir_name . '.zip');
  }
  else {
    return file( 'reffind_' . $self->_renamed_id . '.zip' );
  }
}

#---------------------------------------

# generate the destination path for symlinks

sub _build_symlink_dest {
  my $self = shift;

  # make links in the cwd by default
  my $dest = dir('.');

  # if there's only one reference genome, get the path for its directory and
  # use that as the name of the symlink target, otherwise use the default
  # location, which is the current working directory
  if ( defined $self->_paths and scalar @{ $self->_paths } == 1 ) {
    my $path = $self->_paths->[0];
    if ( $path->isa('Path::Class::File') ) {
      $dest = file $path->basename;
    }
    else {
      $dest = dir $self->_get_dir_name;
    }
  }

  return $dest;
}

#-------------------------------------------------------------------------------

# based on the path to a single reference genome directory, build a stub for a
# destination filename. Convert a path like
#
#     /lustre/scratch108/pathogen/pathpipe/refs/Yersinia/pestis_CO92
#
# to an string like
#
#     Yersinia_pestis_C092
#
# If there are multiple references in the paths list, bail immediately,
# because we can't sensibly use a single genome name for multiple genomes.

sub _get_dir_name {
  my $self = shift;

  # this only makes sense if there's only a single reference
  return unless scalar @{ $self->_paths } == 1;

  # get the location of the directory containing the references
  my $refs_root = dir( $self->config->{refs_root} );

  # count the number of directories in the path to that dir
  my $length_root_path = $refs_root->dir_list;

  # get the components of the output path, but starting from the root directory
  my @dest_path = $self->_paths->[0]->isa('Path::Class::File')
                ? $self->_paths->[0]->parent->dir_list($length_root_path)
                : $self->_paths->[0]->dir_list($length_root_path);

  # join the remaining directories
  return join '_', @dest_path;
}

#-------------------------------------------------------------------------------

# overwrite two methods that are used by "_make_tar" and "_make_zip" from the
# Archivist Role for gathering filenames and renaming them in the archives.

# we don't actually need to do anything in _collect_filenames. We've already
# found the paths that we're interested in. Just replace the original.

sub _collect_filenames {
  my ( $self, $paths ) = @_;

  return $paths;
}

#---------------------------------------

# used by "_make_tar" and "_make_zip" from the Archivist Role for renaming
# files in the archives.

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

# make symlinks for the specified path
#
# This method should work with a directory or a file, though the filetype is
# set by default to "fa" for this command, so the method is pretty much hard
# wired to only link files.

sub _make_symlinks {
  my ( $self, $paths ) = @_;

  return unless defined $paths;

  if ( scalar @$paths == 1 ) {
    # only one path to link

    my $src = $paths->[0];

    my $dst;
    if ( defined $self->_symlink_dest ) {
      $dst = $self->_symlink_dest;
    }
    else {
      $dst = $src->isa('Path::Class::File')
           ? file $paths->[0]->basename
           : dir $self->_get_dir_name;
    }

    $self->_make_symlink($src, $dst);
  }
  else {
    # multiple paths to link

    # get the location of the directory containing the references
    my $refs_root = dir( $self->config->{refs_root} );

    # count the number of directories in the path to that dir
    my $length_root_path = $refs_root->dir_list;

    # make a directory to hold the multiple links
    my $dest_dir = $self->_symlink_dest;

    try {
      $dest_dir->mkpath unless -d $dest_dir;
    } catch {
      Bio::Path::Find::Exception->throw(
        msg => "ERROR: couldn't make link directory ($dest_dir): $_"
      );
    };

    # should be redundant, but...
    Bio::Path::Find::Exception->throw( msg => "ERROR: not a directory ($dest_dir)" )
      unless -d $dest_dir;

    foreach my $src ( @$paths ) {

      # get the components of the output path, but starting from the root directory
      my $dst;
      if ( $src->isa('Path::Class::File') ) {
        # for files we just want the filename
        $dst = file( $dest_dir, $src->basename );
      }
      else {
        # for directories we want the link to be "genus_species". Chop off the
        # path to the root of the references directories and concatenate the
        # remainder with underscores
        my @dest_path = $src->dir_list($length_root_path);
        $dst = dir( $dest_dir, join '_', @dest_path );
      }

      # create the link
      $self->_make_symlink($src, $dst);
    }
  }

}

#-------------------------------------------------------------------------------

# make a single symlink from $src to $dst

sub _make_symlink {
  my ( $self, $src, $dst ) = @_;

  say STDERR "Creating link from '$src' to '$dst'";

  my $success = 0;
  try {
    $success = symlink( $src, $dst );
  }
  catch {
    # this should only happen if perl can't create symlinks on the current
    # platform
    Bio::Path::Find::Exception->throw( msg => "ERROR: cannot create symlinks: $_" );
  };

  carp qq(WARNING: failed to create symlink for "$src" at "$dst")
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
  say ' [a] all references';

  # ask the user which one they want
  my $term = Term::ReadLine->new('ref');
  my $chosen = $term->readline('Which reference? ');

  # return immediately if there's no valid value
  return unless $chosen =~ m/^((a)|(\d+))$/;
                             # $2   $3
  my $chosen_refs;

  if ( $2 ) {
    # input was "a"
    $chosen_refs = $refs;
  }
  else {
    # input was a number. Make sure it's valid
    if ( $3 >= 1 and
         $3 <= ( scalar @$refs + 1 ) and
         defined $refs->[$3 - 1] ) {
      $chosen_refs = [ $refs->[$3 - 1] ];
    }
  }

  # convert the genome name to a path and print them
  my $paths = $self->_rf->lookup_paths( $chosen_refs, $self->filetype );

  return $paths;
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

