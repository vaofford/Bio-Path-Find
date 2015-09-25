
package Bio::Path::Find::Sorter;

# ABSTRACT: class to sort sets of results from a path find search

use Moose;
use namespace::autoclean;

use Path::Class;

with 'Bio::Path::Find::Role::HasEnvironment',
     'Bio::Path::Find::Role::HasConfig';

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

Inherits C<config> and C<environment> from the roles
L<Bio::Path::Find::Role::HasConfig> and
L<Bio::Path::Find::Role::HasEnvironment>.

=cut

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=cut

sub sort_lanes {
  my ( $self, $lanes ) = @_;

  # convert an array of Bio::Track::Schema::Result::LatestLane objects into a
  # hash, using $lane->name as the key
  my %lanes_by_name = map { $_->name => $_ } @$lanes;

  # sort the keys of that hash using the fiendishly complicated sort function
  # below
  my @sorted_names = sort _lane_sort keys %lanes_by_name;

  # build the sorted list of lanes that we want to return
  my @sorted_lanes;
  push @sorted_lanes, $lanes_by_name{$_} for @sorted_names;

  return \@sorted_lanes;
}

#-------------------------------------------------------------------------------
#- functions -------------------------------------------------------------------
#-------------------------------------------------------------------------------

# this function and "_get_lane_name" are cargo-culted from the equivalent
# methods in the old Path::Find::Sort, with just a few tweaks to tidy up the
# code

sub _lane_sort {
  my ( $lane_a, $end_a ) = _get_lane_name($a);
  my ( $lane_b, $end_b ) = _get_lane_name($b);

  my @a = split m/\_|\#/, $lane_a;
  my @b = split m/\_|\#/, $lane_b;

  # check @a and @b are the same length
  my $len_a = scalar(@a);
  my $len_b = scalar(@b);
  unless ( $len_a == $len_b ) {
    if ( $len_a > $len_b ) {
      push @b, '0' for ( 1 .. ( $len_a - $len_b ) );
    }
    else {
      push @a, '0' for ( 1 .. ( $len_b - $len_a ) );
    }
  }

  for my $i ( 0 .. $#a ) {
    return ( $a cmp $b ) if ( $a[$i] =~ m/\D+/ or $b[$i] =~ m/\D+/ );
  }

  if ( $#a == 2 and $#b == 2 and defined $end_a and defined $end_b ) {
    return $a[0] <=> $b[0]
        || $a[1] <=> $b[1]
        || $a[2] <=> $b[2]
        || $end_a cmp $end_b;
  }
  elsif ( $#a == 2 and $#b == 2 and not defined $end_a and not defined $end_b ) {
    return $a[0] <=> $b[0]
        || $a[1] <=> $b[1]
        || $a[2] <=> $b[2];
  }
  elsif ( $#a == 1 and $#b == 1 and defined $end_a and defined $end_b ) {
    return $a[0] <=> $b[0]
        || $a[1] <=> $b[1]   # I'm fairly sure this is redundant..
        || $end_a cmp $end_b;
  }
  else {
    return $a[0] <=> $b[0]
        || $a[1] <=> $b[1];  # I'm fairly sure this is redundant..
  }
}

#-------------------------------------------------------------------------------

# returns two components of the lane name, the "lane name" and the "end"...

sub _get_lane_name {
  my $lane_name = shift;

  return ( $lane_name, undef ) unless $lane_name =~ m/\//;

  my @dirs = dir( $lane_name )->dir_list;

  # this used to use the "smartmatch" operator, ~~, but that results in a
  # warning about use of an experimental feature... I think this is equivalent
  my ( $tracking_index ) = grep { $dirs[$_] eq 'TRACKING' } 0 .. $#dirs;

  # this look very dodgy... why 5 ? Presumably that's only correct if we
  # stick with the directory hierarchy template that we've always used
  my $lane_index = $tracking_index + 5;
  # TODO make this load a hierarchy template from the config and work to that

  my $end = dir( splice( @dirs, $lane_index + 1 ) );

  return ( $dirs[$lane_index], $end );
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

