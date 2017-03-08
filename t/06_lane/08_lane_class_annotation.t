
use strict;
use warnings;

use Test::More tests => 14;
use Test::Exception;
use Path::Class;

# set up the "linked" directory for the test suite
use lib 't';

use Test::Setup;

unless ( -d dir( qw( t data linked ) ) ) {
  diag 'creating symlink directory';
  Test::Setup::make_symlinks;
}
use_ok('Bio::Path::Find::DatabaseManager');

use Bio::Path::Find::DatabaseManager;

use Log::Log4perl qw( :easy );

# initialise l4p to avoid warnings
Log::Log4perl->easy_init( $FATAL );

use_ok('Bio::Path::Find::Lane::Class::Annotation');

#---------------------------------------

# set up a DBM

my $config = {
  db_root           => dir(qw( t data linked )),
  connection_params => {
    tracking => {
      driver       => 'SQLite',
      dbname       => file(qw( t data pathogen_prok_track.db )),
      schema_class => 'Bio::Track::Schema',
    },
  },
};

my $dbm = Bio::Path::Find::DatabaseManager->new(
  config      => $config,
  schema_name => 'tracking',
);

my $database  = $dbm->get_database('pathogen_prok_track');
my @lane_rows = $database->schema->get_lanes_by_id(['10018_1'], 'lane')->all;

#-------------------------------------------------------------------------------

# set up a row with a single GFF file, for lane 10018_1#2

my $lane_row = $lane_rows[11];   # it's "11" because I set this one up after the
$lane_row->database($database);  # example with two GFF files and the lane rows
                                 # come back from DBIC in alphanumeric order...
# get a Lane
my $lane;

lives_ok { $lane = Bio::Path::Find::Lane::Class::Annotation->new( row => $lane_row ) }
  'no exception when creating an Annotation Lane';

ok $lane->does('Bio::Path::Find::Lane::Role::Stats'), 'lane has Stats Role applied';

# set it up to find the GFF file(s) for the lane
$lane->search_depth(3);
$lane->find_files('gff');

#---------------------------------------

# "_get_stats_row"

my $stats;
lives_ok { $stats = $lane->_get_stats_row('spades', 'contigs.fa.stats', $lane->files->[0]) }
  'no exception when getting stats row';

my $expected_stats = [
  607,
  'Scaffold: Correction, Normalisation, Primer Removal + SPAdes + Improvement',
  '10018_1#2',
  317093,
  undef,
  undef,
  undef,
  undef,
  undef,
  '5983',
  '64',
  '95',
  '225633',
  '30.9',
  3,
  1
];

is_deeply $stats, $expected_stats, 'got expected stats row';

#---------------------------------------

# "_build_stats"

lives_ok { $stats = $lane->stats } 'no exception when getting all stats';

$expected_stats = [
  [
    607,
    'Scaffold: Correction, Normalisation, Primer Removal + SPAdes + Improvement',
    '10018_1#2',
    317093,
    'Streptococcus_suis_P1_7_v1',
    2007491,
    '1.2',
    '0.09',
    'NA',
    5983,
    64,
    95,
    225633,
    30.9,
    3,
    1,
  ],
];

is_deeply $stats, $expected_stats, 'got expected stats';

#-------------------------------------------------------------------------------

# set up a new lane, this time one that has two GFF files, 10018_1#1

$lane_row = $lane_rows[0];
$lane_row->database($database);

# get a Lane

lives_ok { $lane = Bio::Path::Find::Lane::Class::Annotation->new( row => $lane_row ) }
  'no exception when creating an Annotation Lane';

ok $lane->does('Bio::Path::Find::Lane::Role::Stats'), 'lane has Stats Role applied';

# set it up to find the GFF file(s) for the lane
$lane->search_depth(3);
$lane->find_files('gff');

#---------------------------------------

# "_get_stats_row"

lives_ok { $stats = $lane->_get_stats_row('spades', 'contigs.fa.stats', $lane->files->[1]) }
  'no exception when getting stats row';

$expected_stats = [
  607,
  'Scaffold: Correction, Normalisation, Primer Removal + SPAdes + Improvement',
  '10018_1#1',
  397141,
  undef,
  undef,
  undef,
  undef,
  undef,
  '2895',
  '36',
  '73',
  '308610',
  '30.9',
  3,
  1
];

is_deeply $stats, $expected_stats, 'got expected stats row';

#---------------------------------------

# "_build_stats"

lives_ok { $stats = $lane->stats } 'no exception when getting all stats';

$expected_stats = [
  [
    607,
    'Scaffold: IVA',
    '10018_1#1',
    397141,
    'Streptococcus_suis_P1_7_v1',
    2007491,
    '1.3',
    '0.10',
    'NA',
    1167,
    3,
    341,
    385279,
    30.9,
    13,
    6,
  ],
  [
    607,
    'Scaffold: Correction, Normalisation, Primer Removal + SPAdes + Improvement',
    '10018_1#1',
    397141,
    'Streptococcus_suis_P1_7_v1',
    2007491,
    '1.3',
    '0.10',
    'NA',
    2895,
    36,
    73,
    308610,
    30.9,
    3,
    1,
  ],
];

is_deeply $stats, $expected_stats, 'got expected stats';

#-------------------------------------------------------------------------------

# done_testing;

