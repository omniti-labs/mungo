# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use Apache::Test qw();
use Apache::TestRequest qw(GET);

use lib './t/lib';
use lib '../t/lib';
use MungoTestUtils;

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

my %tests;
my $test_count;

BEGIN {
    my $pattern = qr{
                        ^
                        \n
                        mungo-success\n
                        \n
                        $
                }x;

    %tests = (
              'include-relative'  => $pattern,
              'include-string'    => $pattern,
              'include-pass-args' => $pattern,
              'trap-include'      => $pattern,
             );
    $test_count = 4*(scalar keys %tests);
}

use Test::More tests => $test_count;
perform_page_tests('/07-include/', \%tests);

