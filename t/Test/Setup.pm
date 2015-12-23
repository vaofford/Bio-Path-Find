
package Test::Setup;

use Carp qw( croak );
use Path::Class;
use Cwd;

sub make_symlinks {

  croak "ERROR: can't install symlinks on this platform"
    unless eval { symlink( '', '' ); 1 };

  my $links_file = file('t', 'data', 'links.txt');

  croak "ERROR: can't find list of links (should be t/data/links.txt)"
    unless -f $links_file;

  my @links = $links_file->slurp( chomp => 1, split => qr/\s/ );

  my $root     = dir( getcwd )->absolute;
  my $link_dir = dir( $root, 't', 'data', 'linked' );

  croak "ERROR: link directory (t/data/linked) already exists; stopping"
    if -d dir$link_dir;

  $link_dir->mkpath;

  foreach my $link ( @links ) {
    my $from      = dir $link->[0];
    my $to        = dir $link->[1];
    my $to_parent = $to->parent;
    my $to_dir    = $to->basename;

    $to_parent->mkpath;

    chdir $to_parent;

    symlink $from, $to_dir
      or die "ERROR: couldn't link from '$from' to '$to_dir'";

    chdir $root;
  }
}

1;

