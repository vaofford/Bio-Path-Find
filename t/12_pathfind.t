
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Output;
use Path::Class;

# don't initialise l4p here because we want to test that command line logging
# is correctly set up by the AppRole

use_ok('Bio::Path::Find::App::PathFind');

# create a test log file and make sure it isn't already there
my $test_log = file('t/data/12_pathfind/_pathfind_test.log');
$test_log->remove;

# simple find - get samples for a lane
my %params = (
  environment => 'test',
  config_file => 't/data/12_pathfind/test.conf',
  id          => '10018_1',
  type        => 'lane',
);

my $pf;
lives_ok { $pf = Bio::Path::Find::App::PathFind->new(%params) } 'got a new pathfind app object';
isa_ok $pf, 'Bio::Path::Find::App::PathFind', 'pathfind app';
ok $pf->does('Bio::Path::Find::App::Role::AppRole'), 'PathFind class does AppRole';

my $expected = join '', <DATA>;
stdout_is { $pf->run } $expected, 'got expected paths on STDOUT';

ok -f $test_log, 'test log found';

my @log_lines = $test_log->slurp( chomp => 1 );
is scalar @log_lines, 1, 'got one log entry';

done_testing;

$test_log->remove;

__END__
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492530/10018_1#1
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_2/SLX/APP_IN_2_7492527/10018_1#2
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T1_OP2/SLX/APP_T1_OP2_7492533/10018_1#3
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_4/SLX/APP_IN_4_7492537/10018_1#4
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N1_OP2/SLX/APP_N1_OP2_7492529/10018_1#5
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N1_OP1/SLX/APP_N1_OP1_7492528/10018_1#6
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T1_OP1/SLX/APP_T1_OP1_7492532/10018_1#7
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_3/SLX/APP_IN_3_7492536/10018_1#8
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP2/SLX/APP_N2_OP2_7492531/10018_1#9
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_1/SLX/APP_IN_1_7492526/10018_1#10
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T2_OP1/SLX/APP_T2_OP1_7492534/10018_1#11
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T2_OP2/SLX/APP_T2_OP2_7492535/10018_1#12
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_5/SLX/APP_IN_5_7492538/10018_1#13
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N3_OP1/SLX/APP_N3_OP1_7492539/10018_1#14
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N3_OP2/SLX/APP_N3_OP2_7492540/10018_1#15
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N4_OP1/SLX/APP_N4_OP1_7492541/10018_1#16
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N4_OP2/SLX/APP_N4_OP2_7492542/10018_1#17
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N5_OP1/SLX/APP_N5_OP1_7492543/10018_1#18
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N5_OP2/SLX/APP_N5_OP2_7492544/10018_1#19
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T3_OP1/SLX/APP_T3_OP1_7492545/10018_1#20
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T3_OP2/SLX/APP_T3_OP2_7492546/10018_1#21
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T4_OP1/SLX/APP_T4_OP1_7492547/10018_1#22
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T4_OP2/SLX/APP_T4_OP2_7492548/10018_1#23
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T5_OP1/SLX/APP_T5_OP1_7492549/10018_1#24
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T5_OP2/SLX/APP_T5_OP2_7492550/10018_1#25
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_1/SLX/APP_IN_1_7492551/10018_1#27
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_2/SLX/APP_IN_2_7492552/10018_1#28
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N1_OP1/SLX/APP_N1_OP1_7492553/10018_1#29
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N1_OP2/SLX/APP_N1_OP2_7492554/10018_1#30
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP1/SLX/APP_N2_OP1_7492555/10018_1#31
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N2_OP2/SLX/APP_N2_OP2_7492556/10018_1#32
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T1_OP1/SLX/APP_T1_OP1_7492557/10018_1#33
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T1_OP2/SLX/APP_T1_OP2_7492558/10018_1#34
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T2_OP1/SLX/APP_T2_OP1_7492559/10018_1#35
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T2_OP2/SLX/APP_T2_OP2_7492560/10018_1#36
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_3/SLX/APP_IN_3_7492561/10018_1#37
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_4/SLX/APP_IN_4_7492562/10018_1#38
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_IN_5/SLX/APP_IN_5_7492563/10018_1#39
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N3_OP1/SLX/APP_N3_OP1_7492564/10018_1#40
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N3_OP2/SLX/APP_N3_OP2_7492565/10018_1#41
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N4_OP1/SLX/APP_N4_OP1_7492566/10018_1#42
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N4_OP2/SLX/APP_N4_OP2_7492567/10018_1#43
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N5_OP1/SLX/APP_N5_OP1_7492568/10018_1#44
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_N5_OP2/SLX/APP_N5_OP2_7492569/10018_1#45
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T3_OP1/SLX/APP_T3_OP1_7492570/10018_1#46
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T3_OP2/SLX/APP_T3_OP2_7492571/10018_1#47
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T4_OP1/SLX/APP_T4_OP1_7492572/10018_1#48
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T4_OP2/SLX/APP_T4_OP2_7492573/10018_1#49
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T5_OP1/SLX/APP_T5_OP1_7492574/10018_1#50
t/data/linked/prokaryotes/seq-pipelines/Actinobacillus/pleuropneumoniae/TRACKING/607/APP_T5_OP2/SLX/APP_T5_OP2_7492575/10018_1#51
