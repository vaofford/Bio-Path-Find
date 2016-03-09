
package Bio::Path::Find::Lane::Class::QC;

# ABSTRACT: a class that adds QC-find-specific functionality to the B::P::F::Lane class

use Moose;

use Bio::Path::Find::Types qw( :all );

extends 'Bio::Path::Find::Lane';

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

# make the "filetype" attribute require values of type QCType, which is
# actually only "kraken". This is to make sure that this class correctly
# restricts the sorts of files that it will return.

has '+filetype' => (
  isa => QCType,
);

#-------------------------------------------------------------------------------
#- builders for file finding ---------------------------------------------------
#-------------------------------------------------------------------------------

# this sets the mapping between filetype and patterns matching filenames on
# disk. It's potentially used by B::P::F::Lane objects to find files when no
# filetype is specified but, in fact, the mechanism for finding assemblies is
# actually set up to use the three "_get_*" methods below, so the mapping is
# redundant. It's only here for consistency.
#
# this mapping is taken from the original assemblyfind
# (PathFind/lib/Path/Find/CommandLine/Assembly.pm:193)

sub _build_filetype_extensions {
  return {
    kraken => 'kraken.report',
  };
}

#-------------------------------------------------------------------------------

1;

