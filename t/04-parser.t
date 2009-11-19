# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use Apache::Test qw();
use Apache::TestRequest qw(GET);


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


             );
    $test_count = 4*(scalar keys %tests);
}

use Test::More tests => $test_count;

my ($url, $response, $content, $pattern);

foreach my $test_page (sort keys %tests) { # Sort is so the order is repeatable
    my $url = '/04-parser/' . $test_page . '.asp';
    my $response = GET $url;
    ok($response->is_success, "Fetch of $url should be a success");
    my $content = $response->content();
    my $pattern = $tests{$test_page};
    like($content, $pattern, "Content of $url should be correct");
    unlike($content, qr{<\%}, "Content of by-ext $url should not contain mungo start tag '<\%'");
    unlike($content, qr{\%>}, "Content of by-ext $url should not contain mungo end tag '\%>'");
}
