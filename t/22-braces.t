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

# 21-braces
# Goal: make <%= (3+4) * 3 %> dtrt

my $test_count = 0;
my %tests = (
             'braces' => {
                             label => "print",
                             like => qr/21/,
                             todo => "",
                             #hardskip => 1,
                           },
             'plus' => {
                             label => "plus",
                             like => qr/6/,
                             todo => "",
                             #hardskip => 1,
                           },
             'dot' => {
                             label => "dot",
                             like => qr/\.123/,
                             todo => "",
                             #hardskip => 1,
                           },
             'sideeffects' => {
                             label => "sideeffects",
                             like => qr/abderf/,
                             todo => "",
                             #hardskip => 1,
                           },
            );

perform_page_tests('/22-braces/', \%tests, \$test_count);
done_testing($test_count);
  