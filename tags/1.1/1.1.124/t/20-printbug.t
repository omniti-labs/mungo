# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use lib './t/lib';
use lib '../t/lib';
use MungoTestUtils;

use Apache::Test qw();
use Apache::TestRequest qw(GET);

use Test::More;

# 20-printbug.t
# Goal: call print with multiple args

=for page list

printbug.asp
trapped.asp
trapped.inc

=for example output

1234
1-2-3-4

=cut

my $test_count = 0;
my %tests = (
             'printbug' => {
                                   label => "print",
                                   status => 200,
                                   like => qr{^1234\n1-2-3-4$},
                                   todo => "",
                                   #hardskip => 1,
                                  },
             'trapped' => {
                                   label => "trapped",
                                   status => 200,
                                   like => qr{^1234\n1-2-3-4$},
                                   todo => "",
                                   #hardskip => 1,
                                  },
            );


perform_page_tests('/20-printbug/', \%tests, \$test_count);
done_testing($test_count);


