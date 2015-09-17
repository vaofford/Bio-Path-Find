
package Bio::Path::Find;

use v5.10;

use Moo;
use MooX::StrictConstructor;
use MooX::Options;

use Carp qw( croak carp );
use File::Slurp;
use File::Spec;

use Types::Standard qw( ArrayRef Str );
use Type::Utils qw( enum );
use Type::Params qw( compile );
use Bio::Path::Find::Types qw(
  BioPathFindPath
  BioPathFindDatabase
  Environment
  IDType
);

use Bio::Path::Find::Path;
use Bio::Path::Find::Database;

with 'Bio::Path::Find::Role::HasEnvironment',
     'Bio::Path::Find::Role::HasConfig';

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------
#- command-line options --------------------------------------------------------
#-------------------------------------------------------------------------------

option 'id' => (
  is       => 'ro',
  isa      => Str,
  required => 1,
  doc      => 'lane, sample or study ID, or name of file containing IDs',
);

option 'type' => (
  is      => 'ro',
  isa     => IDType,
  default => 'lane',
  doc     => 'ID type; must be one of: study, lane, file, library, sample, species',
);

option 'file_id_type' => (
  is      => 'ro',
  isa     => enum( [qw( lane sample )] ),
  default => 'lane',
  doc     => 'type of IDs in file; must be either "lane" or "sample"',
);

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

has '_find_path' => (
  is      => 'ro',
  isa     => BioPathFindPath,
  lazy    => 1,
  writer  => '_set_find_path',
  builder => '_build_find_path',
);

sub _build_find_path {
  my $self = shift;
  return Bio::Path::Find::Path->new(
    environment => $self->environment,
    config_file => $self->config_file,
  );
}

#---------------------------------------

has '_find_db' => (
  is      => 'ro',
  isa     => BioPathFindDatabase,
  lazy    => 1,
  writer  => '_set_find_db',
  builder => '_build_find_db',
);

sub _build_find_db {
  my $self = shift;
  return Bio::Path::Find::Database->new(
    environment => $self->environment,
    config_file => $self->config_file,
  );
}

#---------------------------------------

# somewhere to store the list of IDs that we'll search for. This could be just
# a single ID from the command line or many IDs from a file
has '_ids' => (
  is      => 'ro',
  isa     => ArrayRef[Str],
  default => sub { [] },
);

#---------------------------------------

# the actual type of the IDs we'll be searching for, since we can't rely on
# "type" to give us that
has '_id_type' => (
  is      => 'rw',
  isa     => enum( [ qw( lane sample ) ] ),
  default => 'lane',
);

#-------------------------------------------------------------------------------
#- construction ----------------------------------------------------------------
#-------------------------------------------------------------------------------

sub BUILD {
  my $self = shift;

  # if "type" is "file", we need to know what type of IDs we'll find in the
  # file
  croak qq(ERROR: if "type" is "file", you must also specify "file_id_type")
    if ( $self->type eq 'file' and not $self->file_id_type );

  # we can't use "type" to tell us reliably what kind of IDs we're working
  # with, since it can be set to "file", in which case we need to look to
  # "file_id_type" for type of IDs in the file...

  if ( $self->type eq 'file' ) {
    $self->_load_ids_from_file($self->id);
    $self->_id_type($self->file_id_type);
  }
  else {
    push @{ $self->_ids }, $self->id;
    $self->_id_type($self->type);
  }

}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

# TODO this method needs to convert $lane->storage_path into a path to the
# TODO symlinked directory hierarchy. The actual code to do the mapping should
# TODO be bolted onto Bio::Path::Find::Path

sub find {
  my $self = shift;

  foreach my $lane ( @{ $self->_find_lanes } ) {
    my $root = $self->_find_path->get_hierarchy_root_dir($lane->database_name);
    my $path = $lane->path;
    print File::Spec->catdir($root, $path), "\n";
  }

}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

sub _find_lanes {
  my $self = shift;

  # look in the config and see if there's a database (or more than one) that
  # must always be searched, e.g. pathogen_pacbio_track
  my $always_search = {};

  # (this is just a workaround for Config::General's stupid handling of
  # single-item lists)
  if ( $self->_config->{always_search} ) {
    my $as = $self->_config->{always_search};
    if ( ref $as eq 'ARRAY' ) {
      $always_search->{$_} = 1 for ( @$as );
    }
    else {
      $always_search->{$as} = 1;
    }
  }

  my $available_schemas  = $self->_find_db->available_database_schemas;
  my $available_db_names = $self->_find_db->available_database_names;

  # walk over the list of available databases and, for each ID, search for
  # lanes matching the specified ID

  # somewhere to store all of the Bio::Track::Schema::Result::LatestLane
  # objects that we find
  my @results;

  DB: foreach my $i ( 0 .. $#$available_db_names ) {
                         # ^^^ see http://www.perlmonks.org/?node_id=624502
    my $schema  = $available_schemas->[$i];
    my $db_name = $available_db_names->[$i];

    # the results for this database
    my $db_results;

    ID: foreach my $id ( @{ $self->_ids } ) {
      my $rs = $schema->get_lanes_by_id($id, $self->_id_type);
      push @$db_results, $rs->all if $rs;
    }

    # move on to the next database unless we got some results
    next DB unless scalar @$db_results;

    # tell every result (a Bio::Track::Schema::Result object) which database it
    # comes from. We need this later to generate paths on disk for the files
    # associated with each result
    $_->database_name($db_name) for ( @$db_results );

    # TODO filter lanes

    $db_results = $self->_sort_lanes($db_results);

    # TODO generate stats

    push @results, @$db_results;

    # TODO this needs more consideration...
    # last DB unless $always_search->{$db_name};
  }

  return \@results;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

sub _sort_lanes {
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

sub _load_ids_from_file {
  my ( $self, $filename ) = @_;

  croak "ERROR: no such file ($filename)"
    unless -f $filename;

  my @ids = grep m/^#/, read_file($filename);

  croak "ERROR: no IDs found in file ($filename)"
    unless scalar @ids;

  push @{ $self->_ids }, @ids;
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

  my @dirs = File::Spec->splitdir( $lane_name );

  # this used to use the "smartmatch" operator, ~~, but that results in a
  # warning about use of an experimental feature... I think this is equivalent
  my ( $tracking_index ) = grep { $dirs[$_] eq 'TRACKING' } 0 .. $#dirs;

  # this look very dodgy... why 5 ? Presumably that's only correct if we
  # stick with the directory hierarchy template that we've always used...
  my $lane_index = $tracking_index + 5;

  my $end = File::Spec->catdir( splice( @dirs, $lane_index + 1 ) );

  return ( $dirs[$lane_index], $end );
}

#-------------------------------------------------------------------------------

1;

