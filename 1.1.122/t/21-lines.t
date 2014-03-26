# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use lib './t/lib';
use lib '../t/lib';
use MungoTestUtils;

use Apache::Test qw();
use Apache::TestRequest qw(GET);

use Test::More;
use Time::HiRes qw(gettimeofday);

use FindBin;
use File::Spec::Functions qw(:ALL);

$| = 1;

# 19-filename.t
# Goal: Exercise Mungo's ability to determine the current filename

my $test_count = 0;
my %tests = (
             'filename' => {
                             label => "filename",
                             eval_dump => rel2abs(
                               catdir(
                                 $FindBin::Bin,
                                 "htdocs",
                                 "21-lines",
                                 "filename.asp"
                               )
                             ),
                             todo => "",
                             #hardskip => 1,
                           },
             'lineno' =>   {
                             label => "lineno",
                             like => qr/1 = 1.*2 = 2.*3 = 3.*5 = 5/s,
                             todo => "",
                             #hardskip => 1,
                           },
            );

perform_page_tests('/21-lines/', \%tests, \$test_count);
done_testing($test_count);
  