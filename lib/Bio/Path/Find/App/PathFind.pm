
package Bio::Path::Find::App::PathFind;

# ABSTRACT: find data for sequencing lanes

use MooseX::App qw( Man BashCompletion );

# configure the app

# don't automatically run a guessed command; shows a "did you mean X" message
# instead
# app_fuzzy 0;

# throw an exception if extra options or parameters are found on the command
# line
app_strict 1;

#-------------------------------------------------------------------------------

=head1 SYNOPSIS

  pf <command> --type <ID type> --id <ID or file> [options]

=head1 DESCRIPTION

The pathfind commands find and display various kinds of information about
sequencing projects. Each command takes an ID or a file containing IDs, and
searches the tracking databases for associated information.

=head1 COMMANDS

The commands:

=head2 accession

Finds accessions associated with lanes. The default behaviour is to list
the accessions, but the command can also show the URLs for retrieving
FASTQ files from the ENA FTP archive, or for retrieving the submitted
file from ENA.

=head2 data

Shows information about the files and directories that are associated with
sequencing runs. The command can also generate archives (tar or zip format)
containing data files for found lanes, or generate symbolic links for the
found files.

=head2 info

Shows information about the samples used for given sequencing runs.

=head1 OPTIONS

Some options.

=cut

# TODO add more POD to flesh out the man page

__PACKAGE__->meta->make_immutable;

1;

