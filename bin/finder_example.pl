#!/usr/bin/env perl

# PODNAME: finder_example.pl
# ABSTRACT: usage example for Bio::Path::Find::Finder

use v5.10; # for "say"

use strict;
use warnings;

use Bio::Path::Find::Finder;
use Bio::Path::Find::Lane::Class::Data;

# initialise Log4perl; if we don't do this, l4p will print a warning about
# not having been initialised...
BEGIN { Log::Log4perl->easy_init($Log::Log4perl::ERROR) };

# set up a hash with the configuration parameters. The required values (and
# usually all that's needed) are "db_root" and "connection_params".
my $config = {
  # path to the data directories
  db_root => $ENV{EXAMPLE_DB_ROOT},

  # database connection parameters
  connection_params => {
    tracking => {
      driver       => 'mysql',
      schema_class => 'Bio::Track::Schema',
      host         => $ENV{EXAMPLE_MYSQL_HOST},
      port         => $ENV{EXAMPLE_MYSQL_PORT},
      user         => $ENV{EXAMPLE_MYSQL_USER},
      pass         => $ENV{EXAMPLE_MYSQL_PASS},
    },
  },
};

# get a Finder object. The constructor requires the configuration, but you can
# optionally also provide the name of a Lane class that should be returned by
# "find_lanes". Different Lane classes are suited to different roles, e.g. the
# Data class will find files such as fastqs, while the Annotation class will
# find GFF files. If you don't specify "lane_class", you'll get back basic
# Bio::Path::Find::Lane objects.
my $f = Bio::Path::Find::Finder->new(
  config     => $config,
  lane_class => 'Bio::Path::Find::Lane::Class::Data',
);

# find lanes. Returns an array of B::P::F::Lane objects
my $lanes = $f->find_lanes(
  ids  => [ '10018_1#1', '10263_4' ],
  type => 'lane',
);

say 'found ' . scalar @$lanes . ' lanes';

foreach my $lane ( @$lanes ) {
  # get the DBIC row object
  my $dbic_row = $lane->row;

  # some values from the database
  my $name = $dbic_row->name;
  my $db   = $dbic_row->database->name;
  my $qc   = $dbic_row->qc_status;

  say qq(found lane $name in database "$db"; QC status "$qc");

  # locations for files
  my $symlink_dir = $lane->symlink_path; # linked dir
  my $storage_dir = $lane->storage_path; # "hashed" dir

  say "linked dir is $symlink_dir (master dir $storage_dir)";

  # find actual files for the lane
  $lane->find_files('fastq'); # "go and find me some fastq files"

  next unless $lane->has_files;

  say 'found ' . $lane->file_count . ' fastq files for lane:';

  say $_ for $lane->all_files; # print paths for all files

  print "\n";
}

