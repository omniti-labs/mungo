# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use Apache::Test qw();
use Apache::TestRequest qw(GET);
use Test::More;
use lib './t/lib';
use lib '../t/lib';
use MungoTestUtils;

# 05-parser.t
# Goal: Confirm that Mungo correctly ignores Perl comments in Perl blocks
#       HTML comments should be passed through

=for example output

<!-- html-comment -->
mungo-output

=cut

# hash-outside-block
# hash-starts-block
# hash-throughout-block
# hash-inside-equals-block
# html-comment
# pod-entire-block

my $test_count;
my %tests = (
             'hash-outside-block' => qr{
                                           ^
                                           \#\n           #
                                           mungo-output   # no whitespace
                                           $
                                   }x,
             'hash-starts-block' => qr{
                                          ^
                                          mungo-output   # no whitespace
                                          $
                                  }x,
             'hash-throughout-block' => qr{
                                              ^
                                              \n           #
                                              mungo-output   # no whitespace
                                              $
                                      }x,
             # BUG - awaiting fix for trac17
             'hash-inside-equals-block' => {
                                            todo => "awaiting fix for trac17",
                                            like => qr{
                                                          ^
                                                          $
                                                  }x,
                                           },
             'html-comment' => qr{
                                     ^
                                     <!--\shtml-comment\s-->\n           #
                                     mungo-output\n   # no whitespace
                                     $
                             }x,
             'pod-entire-block' => qr{
                                         ^
                                         \n+
                                         mungo-output   # no whitespace
                                         $
                                 }x,
            );


perform_page_tests('/05-comments/', \%tests, \$test_count);
done_testing($test_count);
