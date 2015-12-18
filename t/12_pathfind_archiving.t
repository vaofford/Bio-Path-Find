
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Output;
use Test::Warn;
use Path::Class;
use File::Temp qw( tempdir );
use Archive::Tar;
use Archive::Zip qw( :CONSTANTS :ERROR_CODES );
use Cwd;
use Compress::Zlib;
use Digest::MD5 qw( md5_hex );
use Try::Tiny;

use Bio::Path::Find::Finder;

# don't initialise l4p here because we want to test that command line logging
# is correctly set up by the AppRole

use_ok('Bio::Path::Find::App::PathFind');

# set up a temp dir where we can write the archive
my $temp_dir = File::Temp->newdir;
dir( $temp_dir, 't' )->mkpath;
my $orig_cwd = getcwd;
symlink( "$orig_cwd/t/data", "$temp_dir/t/data") == 1
  or die "ERROR: couldn't link data directory into temp directory";
chdir $temp_dir;

#-------------------------------------------------------------------------------

# check filename collection

my %params = (
  config_file      => 't/data/12_pathfind_archiving/test.conf',
  id               => '10018_1',
  type             => 'lane',
  no_progress_bars => 1,
);

my $pf;
lives_ok { $pf = Bio::Path::Find::App::PathFind->new(%params) }
  'got a new pathfind app object';

# get the lanes using the Finder directly
my $f = Bio::Path::Find::Finder->new(
  config_file => 't/data/12_pathfind_archiving/test.conf',
  lane_role   => 'Bio::Path::Find::Lane::Role::PathFind',
);

my $lanes = $f->find_lanes( ids => [ '10018_1' ], type => 'lane', filetype => 'fastq' );
is scalar @$lanes, 50, 'found 50 lanes with ID 10018_1 using Finder';

# we could generate the list of filenames and stats like this:
# my ( @expected_filenames, @expected_stats );
# push @expected_stats, $lanes->[0]->stats_headers;
# foreach my $lane ( @$lanes ) {
#   push @expected_filenames, $lane->all_files;
#   push @expected_stats,     $lane->stats;
# }
# but it's safer to read them from a file in the test suite

my @expected_filenames = file( qw( t data 12_pathfind_archiving expected_filenames.txt ) )->slurp(chomp => 1);
my @expected_stats     = file( qw( t data 12_pathfind_archiving expected_stats.txt ) )->slurp(chomp => 1, split => qr|\t| );

# turn all of the expected filenames into Path::Class::File objects...
for ( my $i = 0; $i < scalar @expected_filenames; $i++ ) {
  $expected_filenames[$i] = file( $expected_filenames[$i] );
}

# check against filenames from the app
my ( $got_filenames, $got_stats );
stderr_unlike { ( $got_filenames, $got_stats ) = $pf->_collect_filenames($lanes) }
  qr/finding files:\s+\d+\%/,
  'no progress bar for _collect_filenames when "no_progress_bars" true';

is_deeply $got_filenames, \@expected_filenames,
  'got expected list of filenames from _collect_filenames';

is_deeply $got_stats, \@expected_stats,
  'got expected stats from _collect_filenames';

# check the writing of CSV files
my $filename = file( $temp_dir, 'written_stats.csv' );
$pf->_write_stats_csv($got_stats, $filename);

@expected_stats = file( qw( t data 12_pathfind_archiving stats.csv ) )
                    ->slurp( chomp => 1, split => qr/,/ );
my @got_stats   = file($filename)
                    ->slurp( chomp => 1, split => qr/,/ );

is_deeply \@got_stats, \@expected_stats, 'written stats file looks correct';

#-------------------------------------------------------------------------------

# check the creation of a tar archive

%params = (
  config_file      => 't/data/12_pathfind_archiving/test.conf',
  id               => '10018_1',
  type             => 'lane',
  no_progress_bars => 1,
);

lives_ok { $pf = Bio::Path::Find::App::PathFind->new(%params) }
  'got a new pathfind app object';

# add the stats file to the archive
push @expected_filenames, file( qw( t data 12_pathfind_archiving stats.csv ) );

my $archive;
lives_ok { $archive = $pf->_build_tar_archive(\@expected_filenames) }
  'no problems adding files to archive';

my @archived_files = $archive->list_files;

is scalar @archived_files, 51, 'got expected number of files in archive';
is $archived_files[0], '10018_1/10018_1#1_1.fastq.gz', 'first file looks right';
# is $archived_files[-1], '10018_1/10018_1#51_1.fastq.gz', 'last file looks right';
is $archived_files[-1], '10018_1/stats.csv', 'last file is stats.csv';

my $gzipped_data = $archive->get_content('10018_1/10018_1#1_1.fastq.gz');
my $raw_data = Compress::Zlib::memGunzip($gzipped_data);
is $raw_data, "some data\n", 'first file has expected content';

my $expected_stats_file = file( qw( t data 12_pathfind_archiving stats.csv ) )->slurp;
my $got_stats_file = $archive->get_content('10018_1/stats.csv');

is $got_stats_file, $expected_stats_file, 'extracted stats file looks right';

#---------------------------------------

# check the exception when we try to add a non-existent file to the archive

push @expected_filenames, file('bad_filename');

warnings_like { $pf->_build_tar_archive(\@expected_filenames) }
  [
    { carped => qr/No such file:/ },
    { carped => qr/No such file in archive/ },
    { carped => qr/couldn't rename/ },
  ],
  'warnings when adding bogus file to archive';

pop @expected_filenames;

#---------------------------------------

# check renaming of files in the archive
%params = (
  config_file      => 't/data/12_pathfind_archiving/test.conf',
  id               => '10018_1',
  type             => 'lane',
  no_progress_bars => 1,
  rename           => 1,
);

lives_ok { $pf = Bio::Path::Find::App::PathFind->new(%params) }
  'no exception with "rename" option';

lives_ok { $archive = $pf->_build_tar_archive(\@expected_filenames) }
  'no problems adding files to archive';

@archived_files = $archive->list_files;

is scalar @archived_files, 51, 'got expected number of files in archive';
is scalar( grep(m/\#/, @archived_files) ), 0, 'filenames have been renamed';

#---------------------------------------

# check compression

%params = (
  config_file      => 't/data/12_pathfind_archiving/test.conf',
  id               => '10018_1',
  type             => 'lane',
  no_progress_bars => 1,
);

$pf = Bio::Path::Find::App::PathFind->new(%params);

my $data = file('t/data/12_pathfind_archiving/test_data.txt')->slurp;
my $compressed_data = $pf->_compress_data($data);
my $compressed_data_copy = $compressed_data; # because memGunzip hoses its input...
my $uncompressed_compressed_data = Compress::Zlib::memGunzip($compressed_data_copy);

is $uncompressed_compressed_data, $data, 'data same before and after compression';

is md5_hex($uncompressed_compressed_data), '8611ce14475a877d3acdbccf319360e1',
  'MD5 for uncompressed data is correct';

#---------------------------------------

# check writing

$filename = file( 'non-existent-dir', 'output.txt.gz' );

throws_ok { $pf->_write_data($compressed_data, $filename) }
  qr/couldn't write output file/,
  'exception when writing to non-existent directory';

$filename = file( $temp_dir, 'output.txt.gz' );

# write out the compressed tar file that we generated earlier
lives_ok { $pf->_write_data($compressed_data, $filename) }
  'no exception when writing file to valid directory';

my $slurped_file = $filename->slurp;
my $uncompressed_slurped_data = Compress::Zlib::memGunzip $slurped_file;

is $uncompressed_slurped_data, $data, 'file written to disk matches original';

#-------------------------------------------------------------------------------

# check creation of a zip archive

%params = (
  config_file      => 't/data/12_pathfind_archiving/test.conf',
  id               => '10018_1',
  type             => 'lane',
  no_progress_bars => 1,
  zip              => 1,
);

$pf = Bio::Path::Find::App::PathFind->new(%params);

# set up the list of expected filenames again from scratch
@expected_filenames = file( qw( t data 12_pathfind_archiving expected_filenames.txt ) )->slurp(chomp => 1);
push @expected_filenames, file( qw( t data 12_pathfind_archiving stats.csv ) );

# turn all of the expected filenames into Path::Class::File objects...
for ( my $i = 0; $i < scalar @expected_filenames; $i++ ) {
  $expected_filenames[$i] = file( $expected_filenames[$i] );
}

my $zip;
lives_ok { $zip = $pf->_build_zip_archive(\@expected_filenames) }
  'no exception when building zip archive';

isa_ok $zip, 'Archive::Zip::Archive', 'zip archive';

my @zip_members = $zip->memberNames;
is scalar @zip_members, 51, 'zip has correct number of members';

is $zip_members[0],  '10018_1/10018_1#1_1.fastq.gz', 'first member has correct name';
is $zip_members[-1], '10018_1/stats.csv', 'last member has correct name';

#-------------------------------------------------------------------------------

# check _make_archive method, which brings together all of the various other
# bits of the archive creation code

# first, make a tar archive

%params = (
  config_file      => 't/data/12_pathfind_archiving/test.conf',
  id               => '10018_1#1',
  type             => 'lane',
  no_progress_bars => 1,
);

$pf = Bio::Path::Find::App::PathFind->new(%params);

$lanes = $f->find_lanes( ids => [ '10018_1#1' ], type => 'lane', filetype => 'fastq' );

output_like { $pf->_make_archive($lanes) }
  qr/prokaryotes/,                                    # STDOUT
  qr/pathfind_10018_1_1\.tar\.gz.*?Building tar file/s, # STDERR
  'stdout shows correct contents, stderr shows correct filename for tar archive';

$archive = file( $temp_dir, 'pathfind_10018_1_1.tar.gz' );

ok -f $archive, 'found tar archive';

# check the archive
my $tar = Archive::Tar->new;

lives_ok { $tar->read($archive) } 'no problem reading tar archive';
is_deeply [ $tar->list_files ], [ '10018_1_1/10018_1#1_1.fastq.gz', '10018_1_1/stats.csv' ],
  'got expected files in tar archive';

# check we can write uncompressed tar files
$params{no_tar_compression} = 1;

$pf = Bio::Path::Find::App::PathFind->new(%params);

$lanes = $f->find_lanes( ids => [ '10018_1#1' ], type => 'lane', filetype => 'fastq' );

output_like { $pf->_make_archive($lanes) }
  qr/prokaryotes/,                                    # STDOUT
  qr/pathfind_10018_1_1\.tar(?!\.gz).*?Building tar file/s, # STDERR
  'stdout shows correct contents, stderr shows correct filename for tar archive';

# check for errors when writing

$params{archive} = '/non-existent-dir/test.tar.gz';

$pf = Bio::Path::Find::App::PathFind->new(%params);

my $exception_thrown = 0;
try {
  stderr_like { $pf->_make_archive($lanes) }
    qr/non-existent-dir.*?ERROR: couldn't write output file/,
    'exception when writing tar to expected (broken) location';
} catch {
  $exception_thrown = 1;
};

ok $exception_thrown, 'exception with write failure';

#---------------------------------------

# create a zip archive

delete $params{archive};
$params{zip} = 1;

$pf = Bio::Path::Find::App::PathFind->new(%params);

output_like { $pf->_make_archive($lanes) }
  qr/prokaryotes/,                                 # STDOUT
  qr/pathfind_10018_1_1\.zip.*?Writing zip file/s, # STDERR
  'stdout shows correct contents, stderr shows correct filename for zip archive';

$archive = file( $temp_dir, 'pathfind_10018_1_1.zip' );

ok -f $archive, 'found zip archive';

$zip = Archive::Zip->new;

is $zip->read("$archive"), AZ_OK, 'no problem reading zip archive';
is_deeply [ $zip->memberNames ], [ '10018_1_1/10018_1#1_1.fastq.gz', '10018_1_1/stats.csv' ],
  'got expected files in zip archive';

# check for errors when writing

$params{archive} = file '/non-existent-dir/test.zip';

$pf = Bio::Path::Find::App::PathFind->new(%params);

$exception_thrown = 0;
try {
  stderr_like { $pf->_make_archive($lanes) }
    qr|non-existent-dir.*?Can't open /non-existent-dir/test.zip|,
    'exception when writing zip to expected (broken) location';
} catch {
  $exception_thrown = 1;
};

ok $exception_thrown, 'exception with write failure';

#-------------------------------------------------------------------------------

done_testing;

chdir $orig_cwd;

