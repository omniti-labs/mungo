# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use Apache::Test qw();
use Apache::TestRequest qw(GET);

use lib './t/lib';
use lib '../t/lib';
use MungoTestUtils;
use Test::More;

# 12-end.t
# Goal: Exercise Mungo's Response->End() ability

=for page list

preceding-text.asp
within-loop
no-following-text.asp
extra-header.asp

=for example output

mungo-success

=cut

my $test_count = 0;
our $TODO;
my %tests = (

             'preceding-text' => {
                                  label => "Page with text before End()",
                                  status => 200,
                                  like => qr{^mungo-success$},
                                  todo => "",
                                 },
             'no-following-text' => {
                                     label => "Page with text after End()",
                                     status => 200,
                                     like => qr{^mungo-success$},
                                     todo => "",
                                    },
             'within-loop' => {
                               label => "End() inside loop",
                               status => 200,
                               like => qr{^mungo-success\n123456$},
                               todo => "",
                              },

             'headers-preceding-end' => {
                                         label => "Page with headers prior to End",
                                         status => 200,
                                         like => qr{^\nmungo-success\n$},
                                         header => [ 'X-mungo-test-header' => 'ponies' ],
                                        },
            );

foreach my $test (sort keys %tests) {
    my %info = %{$tests{$test}};
    my $url = '/12-end/' . $test . '.asp';
    my $response = GET $url;
    my $label = $info{label};
    my $status = $info{status};

  TODO: {
        local $TODO = $info{todo};
        is($response->code(), $status, "$label should return a code $status");
        $test_count++;

        my $content = $response->content();
        like($content, $info{like}, "$label should have the correct content on the response");
        $test_count++;

        if ($info{header}) {
            my ($name, $value) = @{$info{header}};
            my $saw = $response->header($name);
            is($saw, $value, "$label should have header value on response");
            $test_count++;
        }
    }
}


done_testing($test_count);


