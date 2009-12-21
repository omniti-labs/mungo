# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use lib './t/lib';
use lib '../t/lib';
use MungoTestUtils;

use Apache::Test qw();
use Apache::TestRequest qw(GET);


use Test::More;

# 11-redirect.t
# Goal: Exercise Mungo's Response->Redirect capability

=for page list

preceding-text - ensure that output prior to the redirect gets sent as content
no-following-text - ensure that text following the redirect DOES NOT get sent as content

=for example output

mungo-success

or

mungo-redirected-success

=cut


Apache::TestRequest::user_agent
  (
   reset => 1,
   requests_redirectable => 0,
  );

my $test_count;
our $TODO;
my %tests = (
          'preceding-text' => {
                               label => "Page with text before redirect",
                               status => 500,
                               initial_like => qr{Cannot redirect, headers already sent},
                               todo => "Status code waiting on fix for trac16",
                              },
          'no-following-text' => {
                                  label => "Page with text after redirect",
                                  status => 302,
                                  initial_like => qr{^$},
                                  redirect_like => qr{^mungo-redirect-success$},
                                 },
          'headers-preceding-redirect' => {
                                           label => "Page with headers prior to redirect",
                                           status => 302,
                                           initial_like => qr{^$},
                                           initial_header => [ 'X-mungo-test-header' => 'ponies' ],
                                           redirect_like => qr{^mungo-redirect-success$},
                                           #todo => "",
                                          },
         );

foreach my $test (sort keys %tests) {
    my %info = %{$tests{$test}};
    my $url = '/11-redirect/' . $test . '.asp';
    my $response = GET $url;
    my $label = $info{label};
    my $status = $info{status};

  TODO: {
        local $TODO = $info{todo};
        is($response->code(), $status, "$label should return a code $status");
        $test_count++;

        my $content = $response->content();
        like($content, $info{initial_like}, "$label should have the correct content on the initial response");
        $test_count++;

        if ($info{initial_header}) {
            my ($name, $value) = @{$info{initial_header}};
            my $saw = $response->header($name);
            is($saw, $value, "$label should have header value on initial response");
            $test_count++;
        }

        if ($response->is_redirect) {
            my $url = $response->header("location");
            my $rd_response = GET $url;
            is($rd_response->code, 200, "$label should be redirected to a page with 200 status");
            $test_count++;

            if ($info{redirect_like}) {
                my $rd_content = $rd_response->content();
                like($rd_content, $info{redirect_like}, "$label should have the correct content on the redirected page");
                $test_count++;
            }
        }
    }
}

done_testing($test_count);
