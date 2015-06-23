# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use lib './t/lib';
use lib '../t/lib';
use MungoTestUtils;

use Apache::Test qw();
use Apache::TestRequest qw(GET);
use Test::More;


# 06-blocks.t
# Goal: Exercise Mungo's handling of Perl Blocks

=for page list

bare-block
if
if-else
if-elsif-else
for
for-next
for-last
while

=for example output (conditionals)

mungo-success

=for example output (loops)

1
2
3
4
5
6
7
8
9
mungo-success

=cut

my $test_count;
my $cond_pattern = qr{
                         ^
                         \n
                         mungo-success\n
                         \n
                         $
                 }x;
my $loop_pattern = qr{
                         ^
                         \n*1\n*2\n*3\n*4\n*5\n*6\n*7\n*8\n*9\n+
                         mungo-success
                         $
                 }x;

my %tests = (
             'bare-block'    => $cond_pattern,
             'if'            => $cond_pattern,
             'if-else'       => $cond_pattern,
             'if-elsif-else' => $cond_pattern,
             'unless'        => $cond_pattern,
             'for'           => $loop_pattern,
             'for-next'      => $loop_pattern,
             'for-last'      => $loop_pattern,
             'while'         => $loop_pattern,
            );

perform_page_tests('/06-blocks/', \%tests, \$test_count);
done_testing($test_count);

