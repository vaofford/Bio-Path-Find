
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Warn;

BEGIN {
  $ENV{TEST_PATHFIND} = 1;
}

use_ok('Bio::Path::Find::Path');

# make sure we can't instantiate the object with unknown arguments
throws_ok { Bio::Path::Find::Path->new(unknown => 'attr') }
  qr/Found unknown attribute/,
  "can't instantiate with unknown argument";

# no config file specified, so the object should load the config that's hard-coded
my $p;
lives_ok { $p = Bio::Path::Find::Path->new }
  'got new B::M::F::Path object successfully';

is $p->environment, 'test', 'object is in test environment';
ok -d $p->db_root, 'found root dir';
is $p->config_file, 't/data/03_has_config/test.conf', 'loaded default config';

# test configs with missing parameters, which should use default values but also
# result in still-working objects

# missing db_root
$p = Bio::Path::Find::Path->new(config_file => 't/data/04_find_path/no_db_root.conf');
warning_like { $p->db_root }
  qr/does not specify the path to the root directory/,
  'got warning about missing "db_root" parameter in config';
is $p->db_root, 't/data/04_find_path/root_dir', 'got expected path to root dir';

# missing db_subdirs mapping
my $returned_subdirs;
$p = Bio::Path::Find::Path->new(config_file => 't/data/04_find_path/no_subdirs.conf');
warning_like { $returned_subdirs = $p->db_subdirs }
  qr/does not specify the mapping between database name and/,
  'got warning about missing "db_subdirs" parameter in config';

my $expected_subdirs = {
  pathogen_virus_track    => 'viruses',
  pathogen_prok_track     => 'prokaryotes',
  pathogen_euk_track      => 'eukaryotes',
  pathogen_helminth_track => 'helminths',
  pathogen_rnd_track      => 'rnd',
};
is_deeply $returned_subdirs, $expected_subdirs, 'got expected defaults for subdir mapping';

# missing hierarchy template
$p = Bio::Path::Find::Path->new(config_file => 't/data/04_find_path/no_template.conf');
warning_like { $p->hierarchy_template }
  qr/does not specify the directory hierarchy/,
  'got warning about missing "hierarchy_template" parameter in config';
is $p->hierarchy_template, 'genus:species-subspecies:TRACKING:projectssid:sample:technology:library:lane',
  'got expected default template';

$p = Bio::Path::Find::Path->new(config_file => 't/data/04_find_path/test.conf');
is $p->get_tracking_name_from_database_name('pathogen_virus_track'), 'viruses',
  'got correct mapping from database name';
is $p->get_tracking_name_from_database_name('non-existent-db'), 'non-existent-db',
  'got correct mapping for database without a mapping';

is $p->get_hierarchy_root_dir('pathogen_test_pathfind'),
  't/data/04_find_path/root_dir/pathogen_test_pathfind/seq-pipelines',
  'got correct root path for test DB';
is $p->get_hierarchy_root_dir('pathogen_prok_track'),
  't/data/04_find_path/root_dir/prokaryotes/seq-pipelines',
  'got correct root path for prokaryotes test DB';

is $p->get_hierarchy_root_dir('non-existent-db'), undef, 'got "undef" for non-existent DB root dir';

$DB::single = 1;

done_testing;

