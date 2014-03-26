# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use lib './t/lib';
use lib '../t/lib';
use MungoTestUtils;

use Apache::Test qw();
use Apache::TestRequest qw(GET);
use Test::More;


# 07-blocks.t
# Goal: Exercise Mungo's include and trap-include functionality

=for page list

trap-include
include-string
include-relative
include-absolute # TODO - not sure how to get absolute path in test env
include-pass-args

=for example output

mungo-success

=cut

my $test_count;

my $pattern = qr{
                    ^
                    \n
                    mungo-success\n
                    \n
                    $
            }x;

my %tests = (
             'include-relative'  => $pattern,
             'include-string'    => $pattern,
             'include-pass-args' => $pattern,
             'trap-include'      => $pattern,
            );

perform_page_tests('/07-include/', \%tests, \$test_count);
done_testing($test_count);

