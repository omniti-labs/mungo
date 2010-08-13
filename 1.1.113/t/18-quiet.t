# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use lib './t/lib';
use lib '../t/lib';
use MungoTestUtils;

use Apache::Test qw();
use Apache::TestRequest qw(GET);

use Test::More;
use Time::HiRes qw(gettimeofday);

$| = 1;

# 18-quiet.t
# Goal: Exercise Mungo::Quiet's error handling

my $test_count = 0;
my %tests = (
             # All of these depend on having Mungo::Quiet set as the perlhandler in 
             # t/conf/extra.conf.in
             'bad-use' => {
                           label => "Bad module load",
                           status => 500,
                           error_log_scanner => make_scanner(qr{Can't locate No/Such/Module\.pm}),
                           like => qr{<h1>Internal Server Error</h1>},
                           todo => "",
                           #hardskip => 1,
                          },
            );

perform_page_tests('/18-quiet/', \%tests, \$test_count);
done_testing($test_count);

sub make_scanner {
    my $regex = shift;
    return sub {
        my $info = shift;
        my @error_log_entries = @_;
        my $log = join "\n", @error_log_entries;
        like($log, $regex, "$info->{label} should have the right Apache error log content");
        $test_count++;
    };
}

