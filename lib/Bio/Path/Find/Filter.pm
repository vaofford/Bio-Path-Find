
package Bio::Path::Find::Filter;

# ABSTRACT: class to filter sets of results from a path find search

use Moose;
use namespace::autoclean;

use Path::Class;
use Types::Standard qw( HashRef Str );
use Bio::Path::Find::Types qw(
  BioPathFindDatabaseManager
);

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

has 'db_manager' => (
  is       => 'ro',
  isa      => BioPathFindDatabaseManager,
  required => 1,
);

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

has '_type_extensions' => (
  is      => 'ro',
  isa     => HashRef[Str],
  default => sub {
    {
      fastq  => '.fastq.gz',
      bam    => '.bam',
      pacbio => '*.h5',
    };
  },
);

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=cut

sub filter_lanes {
  my ( $self, $lanes ) = @_;

  foreach my $lane ( @$lanes ) {

    # if filetype is MAPSTAT_ID:
    #   _get_mapstat_id

    # if there's a date, check its format

    # next lane unless either $qc is not set, or it is set and the lane has
    # that QC status:


    $DB::single = 1;

  }

  return $lanes;
}

#-------------------------------------------------------------------------------

=head2 find_files_for_lane

=cut

sub find_files_for_lane {
  my ( $self, $lane, $type ) = @_;

  # this is the B::P::F::Database object for the database from which this
  # lane was derived
  my $database = $self->db_manager->get_database($lane->database_name);

  # root directory for files related to this database
  my $root_dir = $database->hierarchy_root_dir;

  # the canonical path to the files for this lane
  my $storage_path = dir($root_dir, $lane->storage_path);

  # the symlinked path to the files for the lane
  my $symlink_path = dir($root_dir, $lane->path);

  # the extension for the specified type of file
  my $extension = $self->_type_extensions->{$type};

  # look first for files with the specified extension on the storage path for
  # the files. The storage path is the canonical path to files on the nexsans
  my $path = file( $storage_path, $extension );
  return [ $path ] if ( $storage_path and -e $path );

  # look next on the symlinked directory path
  $path = file( $symlink_path, $type );
  return [ $path ] if -e $path;

  my $files_rs = $lane->latest_files;

  if ( defined $extension and $extension =~ m/fastq/ ) {
    $extension =~ s/\*//;
    my @files;
    while ( my $file = $files_rs->next ) {
      my $path = file( $symlink_path, $file->name );
      push @files, $path->stringify if ( $file->name =~ m/$extension/ and -e $path );
    }
    return \@files if scalar @files;
  }

}

    # if(defined $type_extn && $type_extn =~ /fastq/){
	# $type_extn =~ s/\*//;
    #     foreach my $f ( @{$lane_obj->files} ){
    #         my $file_from_obj = $f->name;
    #         push(@matches, "$full_path/$file_from_obj") if ( $file_from_obj =~ /$type_extn/ && -e "$full_path/$file_from_obj");
    #     }
    #     return \@matches if( @matches );
    # }
# sub find_files_for_lane {
#   my ( $self, $lane, $type ) = @_;
#
#   my $database_name = $lane->database_name;
#   my $storage_path  = $lane->storage_path;
#   my $symlink_path  = $lane->path;
#   my $extension     = $self->_type_extension->{$type};
#
#   # look first for files with the specified extension on the storage path
#   # for the files. The storage path is the path to files on the nexsans
#   my $path = File::Spec->catdir( $storage_path, $extension );
#   return [ $path ] if ( $storage_path and -e $path );
#
#   # look next on the symlinked directory path
#   $path = File::Spec->catdir( $symlink_path, $type );
#   return [ $path ] if -e $path;
#
#   # if ( defined $extension and $extension eq 'fastq' ) {
#   #   my $files_rs = $lane->latest_file->name
#   # }
#
#     # my ( $self, $full_path, $type_extn,$lane_obj, $subdir ) = @_;
#     #
#     #
#     # # If there is a storage path - lookup nexsan directly instead of going via lustre, but return the lustre path
#     # # There a potential for error here but its a big speed increase.
#     # my $storage_path = $lane_obj->storage_path;
#     # if(defined($storage_path) && -e "$storage_path$subdir/$type_extn" )
#     # {
#     #   push( @matches, "$full_path/$type_extn" );
#     #   return \@matches;
#     # }
#     # elsif ( -e "$full_path/$type_extn" ) {
#     #     push( @matches, "$full_path/$type_extn" );
#     #     return \@matches;
#     # }
#     #
#     # if(defined $type_extn && $type_extn =~ /fastq/){
# 	# $type_extn =~ s/\*//;
#     #     foreach my $f ( @{$lane_obj->files} ){
#     #         my $file_from_obj = $f->name;
#     #         push(@matches, "$full_path/$file_from_obj") if ( $file_from_obj =~ /$type_extn/ && -e "$full_path/$file_from_obj");
#     #     }
#     #     return \@matches if( @matches );
#     # }
#     #
#     # my $file_query;
#     # if ( defined($type_extn) && $type_extn =~ /\*/ ) {
#     #     $file_query = $type_extn;
#     # }
#     # #elsif (defined( $self->type_extensions )
#     # #    && defined( $self->alt_type )
#     # #    && defined( $self->type_extensions->{ $self->alt_type } ) )
#     # #{
#     # #    $file_query = $self->alt_type;
#     # #}
#     # elsif ( defined( $self->type_extensions ) && defined( $self->type_extensions->{$type_extn} ) ) {
#     #     $file_query = $self->type_extensions->{$type_extn};
#     # }
#     #
#     # if ( defined($file_query) ) {
#     #     @matches = File::Find::Rule->file()->extras( { follow => 1 } )->maxdepth($self->search_depth)->name($file_query)->in($full_path);
#     # }
#     #
#     # return \@matches;
# }

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

