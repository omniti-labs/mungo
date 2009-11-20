# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use Apache::Test qw();
use Apache::TestRequest qw(GET);

use lib './t/lib';
use lib '../t/lib';
use MungoTestUtils;

# 04-parser.t
# Goal: Confirm that the Mungo parser correctly assembles simple things in the right order with the right spaces.
# Output generally looks like this, with some variations to test various features

=for example

Leader
1234567891011123..100
Trailer

=cut

# no-trailer
# interpolated-trailer
# no-leader-no-trailer
# literal-trailer

my %tests;
my $test_count;

BEGIN {
    %tests = (
              'no-trailer' => qr{
                                    ^
                                    Leader\n      # newline in file => newline in output
                                    12345\d+100   # no whitespace
                                    $
                            }x,
              'interpolated-trailer' => qr{
                                              ^
                                              Leader\n
                                              12345\d+100   # no whitespace
                                              Trailer       # no whitespace
                                              $
                                      }x,
              'no-leader-no-trailer' => qr{
                                              ^
                                              12345\d+100   # no whitespace
                                              $
                                      }x,
              'literal-trailer' => qr{
                                         ^
                                         12345\d+100\n
                                         Trailer
                                         $
                                 }x,
              'printed-trailer' => qr{
                                         ^
                                         Leader\n
                                         12345\d+100   # no whitespace
                                         Trailer       # no whitespace
                                         $
                                 }x,
              'printed-trailer-newline' => qr{
                                                 ^
                                                 Leader\n
                                                 12345\d+100   # no whitespace
                                                 Trailer\n       # literal newline in print
                                                 $
                                         }x,
              'quoted-start-tag-bug17' => {
                                           todo => "Awaiting bugfix on trac ticket 17",
                                           like => qr{
                                                         ^
                                                         \n
                                                         mungo-success\n
                                                         \n
                                                 }x,
                                          },
             );
    $test_count = 4*(scalar keys %tests);
}

use Test::More tests => $test_count;

perform_page_tests('/04-parser/', \%tests);
