
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
sequencing projects.

Run "pf man" to see more documentation about this main "pf" command, or "pf
<command> --help" to see documentation about a particular sub-command,
particular the options that each command accepts.

=head1 COMMANDS

These are the available commands:

=head2 accession

Finds accessions associated with lanes. The default behaviour is to list
the accessions, but the command can also show the URLs for retrieving
FASTQ files from the ENA FTP archive, or for retrieving the submitted
file from ENA.

=head2 data

Shows information about the files and directories that are associated with
sequencing runs. The command can also generate archives (tar or zip format)
containing data files for found lanes, or create symbolic links to data files.

=head2 info

Shows information about the samples used for given sequencing runs.

=head1 COMMON OPTIONS

=head2 Required options

All commands have require two options:

=over

=item --id, -i <ID or filename>

The ID for which to search. The ID can be given on the command line using
C<-i>, or, if you have lots of IDs to find, they can be read from a file or
from STDIN. To read from file, set C<--id> to the name of the file containing
the IDs, or to C<-> to read from STDIN.

When reading from file or STDIN, C<--type> must be set to C<file>, and you
must give the ID type using C<--file-id-type>.

=item --type, -t <type>

The type of ID(s) to look for, or C<file> to read IDs from a file. Type must
be one of C<lane>, C<file>, C<library>, C<sample>, C<species>, or C<study>.

=back

If C<--type> is C<file> then C<--file-id-type> must be specify the type of
ID(s) found in the file..

=head2 Further options

=over

=item --file-id-type, --ft <ID type>

Specify the type ID that is found in a file of IDs. Required when C<--type>
is set to C<file>.

=item --no-progress-bars, -n

Don't show progress bars. The default behaviour is to show progress bars
when running in an interactive session (progress bars are not shown when
running non-interactively, as when called by a script).

=item --csv-separator, -c <separator>

When writing comma separated values (CSV) files (e.g. when writing statistics
using C<pf data>), use the specified string as a separator. Defaults to comma
(C<,>).

=item --verbose, -v

Show debugging information

=back

=cut

=head1 CONFIGURATION VIA ENVIRONMENT VARIABLES

You can set defaults for several options using environment variables. These
values will be overridden if the corresponding option is given on the command
line.

=over

=item PF_TYPE

Set a value for C<--type>. This can still be overridden using the C<--type>
command line option, but setting it avoids the need to add the flag if you
only ever search for one type of data.

=item PF_NO_PROGESS_BARS

Set to a true value to avoid showing progress bars, even when running
interactively. Corresponds to C<--no-progress-bars>.

=item PF_CSV_SEP

Set the separator to be used when writing comma separated values (CSV) files.
Corresponds to C<--csv-separator>.

=item PF_VERBOSE

Set to a true value to show debugging information. Corresponds to C<--verbose>.

=back

=cut

# TODO add more POD to flesh out the man page

__PACKAGE__->meta->make_immutable;

1;

