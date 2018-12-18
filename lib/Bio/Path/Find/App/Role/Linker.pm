
package Bio::Path::Find::App::Role::Linker;

# ABSTRACT: role providing methods for creating symlinks for found files

use v5.10; # for "say"

use MooseX::App::Role;

=head1 CONTACT

path-help@sanger.ac.uk

=cut

use Path::Class;
use Try::Tiny;
use Bio::Path::Find::Exception;

use Types::Standard qw(
  +Bool
);

use Bio::Path::Find::Types qw(
  PathClassEntity
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
    $self->_symlink_dest( dir $new );
  }
  else {
    # don't make links. Shouldn't ever get here
    $self->_symlink_flag(0);
  }
}

# private attributes to store the (optional) value of the "symlink" attribute.
# When using all of this we can check for "_symlink_flag" being true or false,
# and, if it's true, check "_symlink_dest" for a value
has '_symlink_flag' => ( is => 'rw', isa => Bool );

has '_symlink_dest' => (
  is      => 'rw',
  isa     => PathClassEntity,
  lazy    => 1,
  builder => '_build_symlink_dest',
  clearer => '_clear_symlink_dest',    # for use during testing
);

# specify the default destination for creating symlinks here, so that it can be
# overridden by a method in a Lane that applies this Role
sub _build_symlink_dest {
  my $self = shift;
  return dir( 'pf_' . $self->_renamed_id );
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# make symlinks for found lanes

sub _make_symlinks {
  my ( $self, $lanes ) = @_;

  my $dest = $self->_symlink_dest;

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

  my @links = ();

  foreach my $lane ( @$lanes ) {
    # the call to "make_symlinks" returns a reference to an array containing a
    # list of the entities (files or directories) for which the Lane has
    # successfully created links. We need to collect those and list them later,
    # when we're not in the middle of showing a progress bar
    if ( my $ref = eval { $self->can( 'prefix_with_library_name'  ) } ) {
		push @links, $lane->make_symlinks( dest => $dest, rename => $self->rename, prefix => $self->prefix_with_library_name );
	} else {
		push @links, $lane->make_symlinks( dest => $dest, rename => $self->rename);
	}
    $pb++;
  }

  # walk the list of array refs...
  if ( scalar @links > 1 ) {
    foreach my $lane_links ( @links ) {
      # and walk the array containing the list of linked entities for each Lane
      foreach my $link ( @$lane_links ) {
        say $link;
      }
    }
  }  
}

#-------------------------------------------------------------------------------

1;
