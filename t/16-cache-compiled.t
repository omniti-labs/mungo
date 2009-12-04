# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use Apache::Test qw();
use Apache::TestRequest qw(GET);

use lib './t/lib';
use lib '../t/lib';
use MungoTestUtils;
use Test::More;
use HTTP::Cookies;

# 16-cache-compiled.t
# Goal: Confirm that Mungo caches the compiled version of the ASP in memory

=for page list

echo-compile-time

=cut

my $test_count = 0;


my $url = '/16-cache-compiled/echo-compile-time.asp';
my %compile_time_by_pid;
my $attempts_remaining = 10;

ATTEMPT:
while ($attempts_remaining) {
    $attempts_remaining--;
    my $response = GET $url;

    unless ($response->is_success) {
        fail("Fetching compile time page should be successful");
        $test_count++;
        diag($response->content);
        last ATTEMPT;
    }

    my $content = $response->content();
    my $got;
    eval $content;
    if ($@) {
        fail("Evalling compile time page content should be successful");
        $test_count++;
        diag($content);
        diag($@);
        last ATTEMPT;
    }

    my $pid = $got->{pid};

    if (exists $compile_time_by_pid{$pid}) {
        # We've hit this server process before.  The times should match.
        is($got->{compile_time}, $compile_time_by_pid{$pid}, "Pulling page from same server PID should result in same compile timestamp");
        $test_count++;
        last ATTEMPT; # We know what we needed to find out
    }

    # Remember the compile timestamp
    $compile_time_by_pid{$pid} = $got->{compile_time};
}

done_testing($test_count);
