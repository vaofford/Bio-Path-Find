
use strict;
use warnings;

use Test::More; # tests => 10;
use Test::Exception;
use Test::Output;
use Path::Class;
use File::Temp;
use Capture::Tiny qw( capture_stderr );
use Cwd;
use Expect;

# set up the "linked" directory for the test suite
use lib 't';

use Test::Setup;

unless ( -d dir( qw( t data linked ) ) ) {
  diag 'creating symlink directory';
  Test::Setup::make_symlinks;
}

# don't initialise l4p here because we want to test that command line logging
# is correctly set up by the App class

use_ok('Bio::Path::Find::App::PathFind::Ref');

# set up a temp dir where we can write files
my $temp_dir = File::Temp->newdir;
dir( $temp_dir, 't' )->mkpath;
my $orig_cwd = getcwd;
symlink dir( $orig_cwd, qw( t data ) ), dir( $temp_dir, qw( t data ) )
  or die "ERROR: couldn't link data directory into temp directory";
chdir $temp_dir;

#-------------------------------------------------------------------------------

# set up a Ref command object

my %params = (
  config => {
    db_root           => dir( qw( t data linked ) ),
    connection_params => {
      tracking => {
        driver       => 'SQLite',
        dbname       => file( qw( t data pathogen_prok_track.db ) )->stringify,
        schema_class => 'Bio::Track::Schema',
      },
    },
    refs_index => file( qw( t data 27_pf_ref refs.index ) )->stringify,
    refs_root  => file( qw( t data 27_pf_ref            ) )->stringify,
  },
  id => 'abc',
);

my $rf;
lives_ok { $rf = Bio::Path::Find::App::PathFind::Ref->new(%params) }
  'got a new Ref command object';

#-------------------------------------------------------------------------------

# test low level methods

# builders and _get_dir_name

is $rf->_symlink_dest, 'pf_abc', 'got expected symlink destination name';
$rf->_clear_symlink_dest;

$rf->_path( file( qw( t data 27_pf_ref genus species file.fa ) ) );
is $rf->_get_dir_name, 'genus_species', '_get_dir_name gives expected path for file';
is $rf->_tar, 'genus_species.tar.gz', 'got expected tar filename';
is $rf->_zip, 'genus_species.zip', 'got expected zip filename';
is $rf->_symlink_dest, 'file.fa', 'got expected symlink destination name';
$rf->_clear_tar_filename;
$rf->_clear_zip_filename;
$rf->_clear_symlink_dest;

$rf->_path( dir( qw( t data 27_pf_ref genus species ) ) );
is $rf->_get_dir_name, 'genus_species', '_get_dir_name gives expected path for dir';
is $rf->_tar, 'genus_species.tar.gz', 'got expected tar filename';
is $rf->_zip, 'genus_species.zip', 'got expected zip filename';
is $rf->_symlink_dest, 'genus_species', 'got expected symlink destination name';

$rf->no_tar_compression(1);
$rf->_clear_tar_filename;
is $rf->_tar, 'genus_species.tar', 'got expected uncompressed tar filename';

# _collect_filenames

my $expected_files = [ file( qw( t data 27_pf_ref genus species file.fa ) ) ];

my $files = $rf->_collect_filenames( file( qw( t data 27_pf_ref genus species file.fa ) ) );
is_deeply $files, $expected_files, 'got expected files from _collect_filenames';

$files = $rf->_collect_filenames( file( qw( t data 27_pf_ref genus species ) ) );
is_deeply $files, $expected_files, 'got expected files from _collect_filenames';

# _rename_file

is $rf->_rename_file('t/data/27_pf_ref/genus/species/file.fa'), 'genus/species/file.fa',
  'file renamed correctly';

# _make_symlinks

# first, see if we can make symlinks in perl on this platform
my $symlink_exists = eval { symlink("",""); 1 }; # see perl doc for symlink

SKIP: {
  skip "can't create symlinks on this platform", 5 unless $symlink_exists;

  my $link_src = file( qw( t data 27_pf_ref genus species file.fa ) );
  my $link_dst = file( $temp_dir, 'link.fa' );

  $rf->_symlink_dest($link_dst);

  my $stderr;
  lives_ok { $stderr = capture_stderr { $rf->_make_symlinks($link_src) } } 'no exception making symlink';
  like $stderr, qr|^Creating link as '$link_dst'\n|s, 'got expected message when linking';
  ok -l $link_dst, 'link found';
  is readlink $link_dst, $link_src, 'link target is correct';

  $link_src = dir( qw( t data 27_pf_ref genus species ) );

  stderr_like { $rf->_make_symlinks($link_src) }
    qr/WARNING: failed to create/,
    'warning when trying to link with invalid target';
}

#-------------------------------------------------------------------------------

# interactivity...

# use "expect" to talk to the command as a user would if they ran the script
# interactively and it found a match to several references. Check that we get
# the expected path when we pick a reference from the match list. On a personal
# note, you have no idea what a right royal pain in the arse it was to get this
# working.

{
  my $config        = file(qw( t data 27_pf_ref interactive.conf ));
  my $command       = file( $orig_cwd, qw( bin pf ) );
  my $expected_path = file( 'path', 'to' );

  local $ENV{PF_CONFIG_FILE} = "$config";
  local $ENV{PERL_RL}        = 'Stub o=0';

  my $expect = Expect->new;
  $expect->log_stdout(0);

  $expect->spawn( 'perl', "$command", 'ref', '-i', 'abcd' )
    or die "ERROR: couldn't spawn 'pf ref' command: $!";

  $expect->expect(10, 'Which reference? ' )
    or warn "WARNING: didn't find prompt";

  $expect->send("1\n");
  ok $expect->expect(undef, '-re', "$expected_path"), 'got expected path';

  $expect->soft_close;
}

#-------------------------------------------------------------------------------

done_testing;

chdir $orig_cwd;

