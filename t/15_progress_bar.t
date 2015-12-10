
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Output;

use_ok( 'Bio::Path::Find::ProgressBar' );

# the progress bar won't behave exactly the same in an interactive and
# non-interactive session, but we can check the basics

my @params = (
  name => 'testing',
  count => 10,
);

my $pb = new_ok( 'Bio::Path::Find::ProgressBar' => \@params, 'progress bar' );

stderr_like { for ( my $i = 0; $i < 10; $i++ ) { $pb->update($i) } }
  qr/testing/,
  'name printed correctly';

$pb = Bio::Path::Find::ProgressBar->new(@params);

stderr_unlike { for ( my $i = 0; $i < 10; $i++ ) { $pb->update($i) } }
  qr/100%/,
  qq(progress bar doesn't complete unless "finished" called);

$pb = Bio::Path::Find::ProgressBar->new(@params);

stderr_like { for ( my $i = 0; $i < 10; $i++ ) { $pb->update($i) }; $pb->finished }
  qr/100%/,
  qq(progress bar goes to 100% when "finished" called);

@params = (
  name => 'testing',
  count => 10,
  silent => 1,
);

$pb = Bio::Path::Find::ProgressBar->new(@params);

output_is { for ( my $i = 0; $i < 10; $i++ ) { $pb->update($i) } }
  undef, # STDOUT empty
  undef, # STDERR empty
  qq(progress bar doesn't print anything when "silent");

done_testing;

