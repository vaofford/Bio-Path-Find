
package Bio::Path::Find::App::PathFind;

# ABSTRACT: find data for sequencing lanes

use MooseX::App qw( Man );

=head1 DESCRIPTION

The pathfind command finds various kinds of information about sequencing
projects.

=cut

# TODO add more POD to flesh out the man page

# don't automatically run a guessed command; shows a "did you mean X" message
# instead
# app_fuzzy 0;

# throw an exception if extra options or parameters are found on the command
# line
app_strict 1;

__PACKAGE__->meta->make_immutable;

1;

