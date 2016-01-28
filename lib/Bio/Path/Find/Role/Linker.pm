
package Bio::Path::Find::Role::Linker;

# ABSTRACT: role providing methods for creating symlinks for found files

use MooseX::App::Role;

=head1 CONTACT

path-help@sanger.ac.uk

=cut

use Cwd;
use Path::Class;
use Try::Tiny;

use Bio::Path::Find::Exception;

use Types::Standard qw(
  +Bool
);

use Bio::Path::Find::Types qw(
  PathClassDir
);

with 'Bio::Path::Find::Role::HasProgressBar';

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# this option can be used as a simple switch ("-l") or with an argument
# ("-l mydir"). It's a bit fiddly to set that up...

option 'symlink' => (
  documentation => 'create symlinks for data files in the specified directory',
  is            => 'ro',
  cmd_aliases   => 'l',
  trigger       => \&_check_for_symlink_value,
  # no "isa" because we want to accept both Bool and Str and it doesn't seem to
  # be possible to specify that using the combination of MooseX::App and
  # Type::Tiny that we're using here
);

# set up a trigger that checks for the value of the "symlink" command-line
# argument and tries to decide if it's a boolean, in which case we'll generate
# a directory name to hold links, or a string, in which case we'll treat that
# string as a directory name.
sub _check_for_symlink_value {
  my ( $self, $new, $old ) = @_;

  if ( not defined $new ) {
    # make links in a directory whose name we'll set ourselves
    $self->_symlink_flag(1);
  }
  elsif ( not is_Bool($new) ) {
    # make links in the directory specified by the user
    $self->_symlink_flag(1);
    $self->_symlink_dir( dir $new );
  }
  else {
    # don't make links. Shouldn't ever get here
    $self->_symlink_flag(0);
  }
}

# private attributes to store the (optional) value of the "symlink" attribute.
# When using all of this we can check for "_symlink_flag" being true or false,
# and, if it's true, check "_symlink_dir" for a value
has '_symlink_dir'  => ( is => 'rw', isa => PathClassDir );
has '_symlink_flag' => ( is => 'rw', isa => Bool );

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# make symlinks for found lanes

sub _make_symlinks {
  my ( $self, $lanes ) = @_;

  my $dest;

  if ( $self->_symlink_dir ) {
    $self->log->debug('symlink attribute specifies a dir name');
    $dest = $self->_symlink_dir;
  }
  else {
    $self->log->debug('symlink attribute is a boolean; building a dir name');
    $dest = dir( getcwd(), 'pathfind_' . $self->_renamed_id );
  }

  try {
    $dest->mkpath unless -d $dest;
  } catch {
    Bio::Path::Find::Exception->throw(
      msg => "ERROR: couldn't make link directory ($dest): $_"
    );
  };

  # should be redundant, but...
  Bio::Path::Find::Exception->throw( msg => "ERROR: not a directory ($dest)" )
    unless -d $dest;

  say STDERR "Creating links in '$dest'";

  my $pb = $self->_create_pb('linking', scalar @$lanes);

  my $i = 0;
  foreach my $lane ( @$lanes ) {
    $lane->make_symlinks( dest => $dest, rename => $self->rename );
    $pb++;
  }
}

#-------------------------------------------------------------------------------

1;
