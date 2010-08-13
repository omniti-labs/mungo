# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use lib './t/lib';
use lib '../t/lib';
use MungoTestUtils;

use Apache::Test qw();
use Apache::TestRequest qw(GET);

use Test::More;
use HTTP::Cookies;

# 15-i18n.t
# Goal: Exercise Mungo's string table facilities

=for page list

no-handler
reverse
bad-handler
exploding-handler


=for example output


=cut

my $test_count = 0;
my %tests = (
             'no-handler' => {
                              label => "No I18N handler",
                              like => qr{^\nmungo-success\nmungo-success$},
                              todo => "",
                              #hardskip => 1,
                             },
             'reverse'    => {
                              label => "Reversing I18N handler",
                              like => qr{^\nmungo-success\nmungo-success$},
                              todo => "",
                              #hardskip => 1,
                             },
             'read-accept-languages' => {
                                         label => "Getting passed a language list",
                                         eval_dump => [
                                                       'en-US',
                                                       'fr-CA',
                                                       'de-DE',
                                                      ],
                                         request_options => { 'Accept-Language' => 'en-US, fr-CA, de-DE' },
                                         todo => "awaiting fix for trac23",
                                         #hardskip => 1,
                                        },
             'read-accept-languages-sorted' => {
                                                label => "Getting passed a language list with preference values",
                                                page => 'read-accept-languages',
                                                eval_dump => [
                                                              'de-DE',
                                                              'fr-CA',
                                                              'en-US',
                                                             ],
                                                request_options => { 'Accept-Language' => 'en-US;q=0.1, fr-CA;q=0.5, de-DE' },
                                                todo => "awaiting fix for trac23",
                                                #hardskip => 1,
                                               },
             'set-read-preferred-lang' => {
                                           label => "Setting and reading the preferred lang",
                                           like => qr{^\nmungo-success\n},
                                           todo => "awaiting fix for trac23",
                                           #hardskip => 1,
                                          },
            );

perform_page_tests('/15-i18n/', \%tests, \$test_count);
done_testing($test_count);
