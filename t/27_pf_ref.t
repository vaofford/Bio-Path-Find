
#-------------------------------------------------------------------------------
#- wrapping class --------------------------------------------------------------
#-------------------------------------------------------------------------------

# the idea of this class is to wrap up the original command class and replace
# the various _make_* methods, which are tested in separate test scripts, with
# dummy "around" modifiers. That will allow us to test the run method without
# actually calling the concrete methods.

package Bio::Path::Find::App::PathFind::TestFind;

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;

extends 'Bio::Path::Find::App::PathFind::Ref';

around '_make_symlinks' => sub {
  print STDERR 'called _make_symlinks';
};

around '_make_tar' => sub {
  print STDERR 'called _make_tar';
};

around '_make_zip' => sub {
  print STDERR 'called _make_zip';
};

#-------------------------------------------------------------------------------
#- main test script ------------------------------------------------------------
#-------------------------------------------------------------------------------

package main;

use strict;
use warnings;

use Test::More tests => 33;
use Test::Exception;
use Test::Output;
use Test::Warn;
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

is $rf->_symlink_dest, '.', 'default link dir is CWD';
$rf->_clear_symlink_dest;

$rf->_paths( [ file( qw( t data 27_pf_ref genus species file.fa ) ) ] );
is $rf->_get_dir_name, 'genus_species', '_get_dir_name gives expected path for file';
is $rf->_tar, 'genus_species.tar.gz', 'got expected tar filename';
is $rf->_zip, 'genus_species.zip', 'got expected zip filename';
is $rf->_symlink_dest, 'file.fa', 'got expected symlink destination name';
$rf->_clear_tar_filename;
$rf->_clear_zip_filename;
$rf->_clear_symlink_dest;

$rf->_paths( [ dir( qw( t data 27_pf_ref genus species ) ) ] );
is $rf->_get_dir_name, 'genus_species', '_get_dir_name gives expected path for dir';
is $rf->_tar, 'genus_species.tar.gz', 'got expected tar filename';
is $rf->_zip, 'genus_species.zip', 'got expected zip filename';
is $rf->_symlink_dest, 'genus_species', 'got expected symlink destination name';

$rf->no_tar_compression(1);
$rf->_clear_tar_filename;
is $rf->_tar, 'genus_species.tar', 'got expected uncompressed tar filename';

# _collect_filenames

my $files = $rf->_collect_filenames( [ 'path' ] );
is_deeply $files, [ 'path' ], 'got expected files from _collect_filenames';

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
  lives_ok { $stderr = capture_stderr { $rf->_make_symlinks( [ $link_src ] ) } } 'no exception making symlink';
  like $stderr, qr|^Creating link from '$link_src' to '$link_dst'\n|s, 'got expected message when linking';
  ok -l $link_dst, 'link found';
  is readlink $link_dst, $link_src, 'link target is correct';

  $link_src = dir( qw( t data 27_pf_ref genus species ) );

  stderr_like { $rf->_make_symlinks( [ $link_src ] ) }
    qr/WARNING: failed to create/,
    'warning when trying to link with invalid target';
}

#-------------------------------------------------------------------------------

# test the "run" method

$params{id} = 'abc';

$rf->clear_config;
$rf = Bio::Path::Find::App::PathFind::Ref->new(%params);

stdout_like { $rf->run } qr|^t.*?\.fa$|, 'got path to fasta from "run"';

$params{reference_names} = 1;

$rf->clear_config;
$rf = Bio::Path::Find::App::PathFind::Ref->new(%params);

stdout_like { $rf->run } qr/^abc$/, 'got reference name from "run"';

#---------------------------------------

$params{id} = 'abcd';

$rf->clear_config;
$rf = Bio::Path::Find::App::PathFind::Ref->new(%params);

stdout_like { $rf->run } qr/^abcde\nabcdefgh$/s, 'got multiple reference names from "run"';

$params{reference_names} = 0;

$rf->clear_config;
$rf = Bio::Path::Find::App::PathFind::Ref->new(%params);

stdout_like { $rf->run } qr|No exact match|, 'got message about multiple matches from "run"';

#---------------------------------------

$params{all} = 1;

$rf->clear_config;
$rf = Bio::Path::Find::App::PathFind::Ref->new(%params);

stdout_like { $rf->run } qr|^t.*?abcde\.fa.*abcdefgh\.fa$|s, 'got multiple fasta paths from "run" using "all"';

#---------------------------------------

$params{id} = 'abc';

$rf->clear_config;
$rf = Bio::Path::Find::App::PathFind::Ref->new(%params);

my $expected_file = file( qw( t data 27_pf_ref abc.fa ) )->stringify;

stdout_like { $rf->run } qr|^$expected_file\n$|, 'got single path from "run"';

#---------------------------------------

$params{id} = 'nomatch';

$rf->clear_config;
$rf = Bio::Path::Find::App::PathFind::Ref->new(%params);

stdout_like { $rf->run } qr|No matching reference|, 'got no match from "run"';

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
  my $expected_path = file(qw( t data 27_pf_ref abcde.fa ));

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

  #---------------------------------------

  # make sure the "all" option behaves as expected
  $expected_path = file( qw( t data 27_pf_ref abcde.fa ) ) . '.*?' .
                   file( qw( t data 27_pf_ref abcdefgh.fa ) );

  $expect = Expect->new;
  $expect->log_stdout(0);

  $expect->spawn( 'perl', "$command", 'ref', '-i', 'abcd' )
    or die "ERROR: couldn't spawn 'pf ref' command: $!";

  $expect->expect(10, 'Which reference? ' )
    or warn "WARNING: didn't find prompt";

  $expect->send("a\n");

  ok $expect->expect(undef, 'abcde.fa'),    'got first expected path when choosing "all"';
  ok $expect->expect(undef, 'abcdefgh.fa'), 'got second expected path when choosing "all"';

  $expect->soft_close;

  #---------------------------------------

  # check behaviour when we give an invalid response
  $expect = Expect->new;
  $expect->log_stdout(0);

  $expect->spawn( 'perl', "$command", 'ref', '-i', 'abcd' )
    or die "ERROR: couldn't spawn 'pf ref' command: $!";

  $expect->expect(10, 'Which reference? ' )
    or warn "WARNING: didn't find prompt";

  $expect->send("X\n");
  ok $expect->expect(undef, '-re', 'No reference chosen'),
    'got expected "no reference chosen" message';

  $expect->soft_close;
}

#-------------------------------------------------------------------------------

# check the dispatching to the _make_* methods
#
# For these methods we can't just set "archive" to a boolean, which would mimic
# the situation when a users runs "pf ref -i whatever -a". That sitation can
# only be tested (as the code is currently written) by running the script using
# something like Test::Script::Run.
#
# Instead, we just make sure we set a non-boolean value for the archive, zip,
# and symlink flags, and that will still trigger the call to _make_tar, etc.,
# which is what we're really trying to check here.

$rf->clear_config;

$params{id}       = 'abc';
$params{filetype} = 'fa';
$params{archive}  = 'my_tar.tar';

my $tf = Bio::Path::Find::App::PathFind::TestFind->new(%params);

stderr_like { $tf->run }
  qr/called _make_tar/,
  'correctly called "_make_tar"';

#---------------------------------------

$rf->clear_config;

$params{archive} = 0;
$params{zip}     = 'my_zip.zip';

$tf = Bio::Path::Find::App::PathFind::TestFind->new(%params);

stderr_like { $tf->run }
  qr/called _make_zip/,
  'correctly called "_make_zip"';

#---------------------------------------

$rf->clear_config;

$params{zip}     = 0;
$params{symlink} = 'my_symlink_target';

$tf = Bio::Path::Find::App::PathFind::TestFind->new(%params);

stderr_like { $tf->run }
  qr/called _make_symlink/,
  'correctly called "_make_symlink"';

#-------------------------------------------------------------------------------

# done_testing;

chdir $orig_cwd;

