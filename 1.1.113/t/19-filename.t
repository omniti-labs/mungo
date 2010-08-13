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

$| = 1;

# 19-filename.t
# Goal: Exercise Mungo's ability to determine the current filename

my $test_count = 0;
my %tests = (
             'one-level' => {
                             label => "One-level",
                             eval_dump => [
                                           '/19-filename/one-level.asp',
                                          ],
                             todo => "",
                             #hardskip => 1,
                            },
             'two-level' => {
                             label => "Two-level",
                             eval_dump => [
                                           '/19-filename/one-level.asp',
                                           '/19-filename/two-level.asp',
                                          ],
                             todo => "",
                             #hardskip => 1,
                            },
             'stringy' => {
                             label => "Stringy",
                             eval_dump => [
                                           'ANON',
                                           '/19-filename/stringy.asp',
                                          ],
                             todo => "",
                             #hardskip => 1,
                          }
            );

perform_page_tests('/19-filename/', \%tests, \$test_count);
done_testing($test_count);
