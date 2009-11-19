# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use Apache::Test qw();
use Apache::TestRequest qw(GET);


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

my %tests;
my $test_count;

BEGIN {
    %tests = (
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
              # BUG - this crashes but with status 200
              #'hash-inside-equals-block' => qr{
              #                                    ^
              #                                    $
              #                            }x,

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
    $test_count = 4*(scalar keys %tests);
}

use Test::More tests => $test_count;

my ($url, $response, $content, $pattern);

foreach my $test_page (sort keys %tests) { # Sort is so the order is repeatable
    my $url = '/05-comments/' . $test_page . '.asp';
    my $response = GET $url;
    ok($response->is_success, "Fetch of $url should be a success");
    my $content = $response->content();
    my $pattern = $tests{$test_page};
    like($content, $pattern, "Content of $url should be correct");
    unlike($content, qr{<\%}, "Content of by-ext $url should not contain mungo start tag '<\%'");
    unlike($content, qr{\%>}, "Content of by-ext $url should not contain mungo end tag '\%>'");
}
