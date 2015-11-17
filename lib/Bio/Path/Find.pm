
package Bio::Path::Find;

# this is a placeholder for a class that needs to do most of the things that
# are currently done by the bin/pathfind script, which is included here in the
# DATA block.

1;

__END__
#!/usr/bin/env perl

# PODNAME: pathfind

use v5.10; # for "say"

use strict;
use warnings;

use Getopt::Long;
use Bio::Path::Find::Finder;

use Types::Standard qw( Str );
use Bio::Path::Find::Types qw(
  IDType
  FileIDType
  QCState
  FileType
  Environment
);

# a mapping that gives the type for each option, plus a short description of
# the type that we can use in an error message
# TODO see if we can use something like Type::Library to do this validation
my %option_types = (
  config       => { type => Str,         desc => 'a string' },
  environment  => { type => Environment, desc => 'either "test" or "prod"' },
  id           => { type => Str,         desc => 'a string' },
  type         => { type => IDType,      desc => 'a valid ID type' },
  filetype     => { type => Str,         desc => 'a string' },
  file_id_type => { type => FileIDType,  desc => 'a valid file ID type' },
  qc           => { type => QCState,     desc => 'either "passed", "failed", or "pending"' },
);

# set option defaults
my %options = (
  config      => 'live.conf',
  environment => 'prod',
  verbose     => 0,
);

# parse the command line options
my $options_parsed_successfully = GetOptions(
  \%options,
  'config=s',
  'environment=s',
  'id=s',
  'type=s',
  'filetype|ft=s',
  'file_id_type|fit=s',
  'qc=s',
  'help|?',
  'verbose+'
);

usage() if $options{help};

exit 1 unless $options_parsed_successfully;

# check for required parameters
unless ( $options{id} and $options{type}) {
  print STDERR "ERROR: you must specify the ID (-id) and ID type (-type)\n";
  exit 1;
}

# check types for supplied options
while ( my ( $option_name, $option_value ) = each %options ) {
  # skip the validation of this option unless we have a type to check for
  next unless $option_types{$option_name};

  my $type = $option_types{$option_name}->{type};
  my $desc = $option_types{$option_name}->{desc};

  unless ( $type->check($option_value) ) {
    print STDERR qq(ERROR: option "$option_name" is not $desc\n);
    exit 1;
  }
}

# get a finder
my $pf = Bio::Path::Find::Finder->new(
  config_file => $options{config},
  environment => $options{environment},
);

# increase the log level in response to the "-verbose" flag
foreach my $category ( qw ( Bio.Path.Find.Finder Bio.Path.Find.Lane Bio.Path.Find.DatabaseManager ) ) {
  $pf->log($category)->more_logging($options{verbose}) if $options{verbose};
}

# turn on DBIC debugging if the "-verbose" option is used multiple times
$ENV{DBIC_TRACE} = 1 if $options{verbose} > 3;

my %parameters = (
  id   => $options{id},
  type => $options{type},
);

# pass only meaningful options on to the find/print method
foreach my $option ( grep ! m/(verbose|config|environment)/, keys %options ) {
  $parameters{$option} = $options{$option} if $options{$option};
}

$pf->print_paths(%parameters);

exit 0;

#-------------------------------------------------------------------------------
#- functions -------------------------------------------------------------------
#-------------------------------------------------------------------------------

sub usage {
  say 'usage: pathfind ...';
  exit 0;
}

