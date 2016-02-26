
use warnings;
use strict;

use Test::More; # tests => 10;
use Test::Output;
use Test::Exception;
use Path::Class;

# initialise l4p to avoid warnings
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init( $FATAL );

use_ok('Bio::Path::Find::RefFinder');

#-------------------------------------------------------------------------------

# make sure we can use the config

# test failure situations. First, empty config

my $rf = Bio::Path::Find::RefFinder->new( config => {} );

throws_ok { $rf->index_file }
  qr/not defined in config/,
  'exception if index location not defined in config';

# next, pointing at non-existent file
my $config = {
  refs_index => 'non-existent-config',
};

# (don't for get to get rid of the existing config singleton)
$rf->clear_config;

$rf = Bio::Path::Find::RefFinder->new( config => $config );

throws_ok { $rf->index_file }
  qr/can't find reference genome index/,
  'exception if index location incorrect';

$rf->clear_config;

# finally, trying to read a bad config file (wrong format)

$config->{refs_index} = file( qw( t data 26_reffind bad.index ) );
$rf = Bio::Path::Find::RefFinder->new( config => $config );

lives_ok { $rf->index_file } 'no exception with valid config and existing index';

throws_ok { $rf->index }
  qr/failed to read anything/,
  'exception when reading invalid config';

$rf->clear_config;

#-------------------------------------------------------------------------------

# check the reading of index files

# get a valid config
my $ref_index_file = file( qw( t data 26_reffind refs.index ) );

# first, specify the file as a string
$config->{refs_index} = $ref_index_file->stringify;

$rf = Bio::Path::Find::RefFinder->new( config => $config );

my $index_file;
lives_ok { $index_file = $rf->index_file } 'no exception getting index file name';

is $index_file, $ref_index_file->stringify, 'got back correct path for index file';

my $index;
lives_ok { $index = $rf->index }
  'no exception getting index with valid config and real index file';

my $expected_index = {
  abc        => '/path/to/abc',
  abcde      => '/path/to/abcde',
  abcdefgh   => '/path/to/abcdefgh',
  abc_def_gh => '/path/to/abc_def_gh',
};

is_deeply $index, $expected_index, 'got expected index';

$rf->clear_config;

# specify the index file as a Path::Class::File object
$config->{refs_index} = $ref_index_file;

$rf = Bio::Path::Find::RefFinder->new( config => $config );

lives_ok { $index = $rf->index } 'no exception when specifying index file as an object';

is_deeply $index, $expected_index, 'read expected index';

#-------------------------------------------------------------------------------

# check reference finding

throws_ok { $rf->find_refs }
  qr/Wrong number of parameters/,
  'exception from Type::Tiny when calling "find_refs" with no args';

throws_ok { $rf->find_refs( {} ) }
  qr/did not pass type constraint/,
  'exception from Type::Tiny when calling "find_refs" with no args';

my $matches;
lives_ok { $matches = $rf->find_refs('no matches') }
  'no exception finding matches with valid search term';

is scalar @$matches, 0, 'no matches as expected';

# look for an exact match
$matches = $rf->find_refs('abc');
is scalar @$matches, 1, 'one match as expected for exact match';
is $matches->[0], 'abc', 'match is correct';

# look for a single regex match
$matches = $rf->find_refs('abc_d');
is scalar @$matches, 1, 'one match as expected with regex';
is $matches->[0], 'abc_def_gh', 'match is correct';

# look for multiple regex matches
$matches = $rf->find_refs('abcd');
is scalar @$matches, 2, 'two matches as expected with regex';

# can't rely on the order of the matches that come back from "find_refs",
# since it creates them in hash order. Map the matches into a hash and
# check that for the expected keys
my %matches = map { $_ => 1 } @$matches;
ok exists $matches{abcde}, 'got one expected match';
ok exists $matches{abcdefgh}, 'got other expected match';

# fuzzy matches...
$matches = $rf->find_refs('ac');
is scalar @$matches, 4, 'four matches as expected with fuzzy search';

$matches = $rf->find_refs('def');
is scalar @$matches, 2, 'two matches as expected with fuzzy search';
%matches = map { $_ => 1 } @$matches;
ok exists $matches{abcdefgh}, 'got one expected match';
ok exists $matches{abc_def_gh}, 'got other expected match';

#-------------------------------------------------------------------------------

# getting paths for genome sequences

my $paths = $rf->lookup_paths('abc');
is scalar @$paths, 1, 'got one path, as expected, using "lookup_paths"';
is $paths->[0], '/path/to/abc', 'got expected path';

$paths = $rf->lookup_paths( ['abc', 'abcde' ] );
is scalar @$paths, 2, 'got two paths';
is $paths->[0], '/path/to/abc', 'got first expected path';
is $paths->[1], '/path/to/abcde', 'got second expected path';

$paths = $rf->lookup_paths( [ 'no-such-genome', 'abc' ] );
is scalar @$paths, 2, 'got two paths';
is $paths->[0], undef, 'first path undefined';
is $paths->[1], '/path/to/abc', 'got second expected path';

#-------------------------------------------------------------------------------

# all-in-one method

$paths = $rf->find_paths('abc');
is scalar @$paths, 1, 'got one path using "find_paths"';
is $paths->[0], '/path/to/abc', 'got expected path';

$paths = $rf->find_paths('def');
is scalar @$matches, 2, 'two matches as expected with fuzzy search through "find_paths"';
%matches = map { $_ => 1 } @$matches;
ok exists $matches{abcdefgh}, 'got one expected match';
ok exists $matches{abc_def_gh}, 'got other expected match';

#-------------------------------------------------------------------------------

done_testing;

