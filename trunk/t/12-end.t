# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use lib './t/lib';
use lib '../t/lib';
use MungoTestUtils;

use Apache::Test qw();
use Apache::TestRequest qw(GET);

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


perform_page_tests('/12-end/', \%tests, \$test_count);
done_testing($test_count);


