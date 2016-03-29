
use strict;
use warnings;

use Test::More tests => 21;
use Test::Exception;
use Test::Output;
use Path::Class;
use Cwd;
use Log::Log4perl;
use Text::CSV_XS qw( csv );

# don't initialise l4p here because we want to test that command line logging
# is correctly set up by the module

use_ok('Bio::Path::Find::App::PathFind');

# set up a temp dir where we can write the archive
my $temp_dir = File::Temp->newdir;
dir( $temp_dir, 't' )->mkpath;
my $orig_cwd = getcwd;
symlink dir( $orig_cwd, qw( t data ) ), dir( $temp_dir, qw( t data ) )
  or die "ERROR: couldn't link data directory into temp directory";
chdir $temp_dir;

# simple find - get samples for a lane
my %params = (
  config_file => file( qw( t data 11_pf_boilerplate test.conf ) ),
  id          => '10018_1',
  type        => 'lane',
);

my $tf;
lives_ok { $tf = Bio::Path::Find::App::PathFind->new(%params) } 'got a new pathfind app object';
isa_ok $tf, 'Bio::Path::Find::App::PathFind', 'pathfind app';

is_deeply $tf->_ids, ['10018_1'], 'IDs set correctly with one ID';
is $tf->type, 'lane', 'type set correctly with ID in parameters';

# check that the renamed ID is generated correctly
$params{id} = '10018_1#1';
$tf = Bio::Path::Find::App::PathFind->new(%params);

is $tf->_renamed_id, '10018_1_1', 'renamed ID correctly generated';

# check ID trimming works
$params{id} = ' 10018_1	';

lives_ok { $tf = Bio::Path::Find::App::PathFind->new(%params) }
  'no exception with ID with flanking whitespace on command line';

is_deeply $tf->_ids, [ '10018_1' ], 'got trimmed ID';

# check behaviour with an invalid ID
$params{id} = '100 18_1';

throws_ok { $tf = Bio::Path::Find::App::PathFind->new(%params) }
  qr/not a valid ID/,
  'exception with invalid ID on command line';

# look for exceptions when reading from file
%params = (
  config_file  => file( qw( t data 11_pf_boilerplate test.conf ) ),
  id           => 'non-existent-file',
  type         => 'file',
  file_id_type => 'lane',
);

throws_ok { $tf = Bio::Path::Find::App::PathFind->new(%params) }
  qr/no such file/,
  'exception with non-existent ID input file';

$params{id} = file( qw( t data 11_pf_boilerplate empty_ids.txt ) )->stringify;

throws_ok { $tf = Bio::Path::Find::App::PathFind->new(%params) }
  qr/no valid IDs found in file/,
  'exception with input file with only bad IDs';

# more complicated - get samples for lane IDs in a file
%params = (
  config_file  => file( qw( t data 11_pf_boilerplate test.conf ) ),
  id           => file( qw( t data 11_pf_boilerplate ids.txt ) )->stringify,
  type         => 'file',
  file_id_type => 'lane',
  verbose      => 1,
);

$tf = Bio::Path::Find::App::PathFind->new(%params);

# check that the IDs and type have been set correctly
is_deeply $tf->_ids, [ '10018_1', '10263' ], 'got ID list from file';
is $tf->_type, 'lane', 'got ID type as "lane"';

# check CSV writing

my $expected_stats_file         = file(qw( t data 11_pf_boilerplate expected_stats.tsv ));
my $expected_stats_file_content = $expected_stats_file->slurp;
my @expected_stats              = $expected_stats_file->slurp( chomp => 1, split => qr|\t| );

throws_ok { $tf->_write_csv }
  qr/must supply some data/,
  'exception with no input';

throws_ok { $tf->_write_csv(\@expected_stats) }
  qr/must supply a filename/,
  'exception when no filename';

my $stats_file = file( $temp_dir, 'stats.csv' );
lives_ok { $tf->_write_csv(\@expected_stats, $stats_file) }
  'no exception with valid stats and filename';

# check that we get out exactly what went in
my $stats = csv( in => $stats_file->stringify );
is_deeply $stats, \@expected_stats, 'written contents look right';

throws_ok { $tf->_write_csv(\@expected_stats, $stats_file) }
  qr/not overwriting/,
  'exception when file already exists';

$params{force} = 1;
my $tf_force = Bio::Path::Find::App::PathFind->new(%params);

lives_ok { $tf_force->_write_csv(\@expected_stats, $stats_file) }
  'no exception when file already exists but "force" is true';

$stats_file->remove;

# write the same data but with a tab separator
$tf->csv_separator("\t");
lives_ok { $tf->_write_csv(\@expected_stats, $stats_file) }
  'no exception writing tab-separated data';

$stats = csv( in => $stats_file->stringify, sep => "\t" );
is_deeply $stats, \@expected_stats, 'tab-separated contents look right';

# done_testing;

chdir $orig_cwd;

