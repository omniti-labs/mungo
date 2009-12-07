# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use Apache::Test qw();
use Apache::TestRequest qw(GET);

use lib './t/lib';
use lib '../t/lib';
use MungoTestUtils;

use HTTP::Cookies;
use Time::HiRes qw(gettimeofday);

$| = 1;

# 17-buffer.t
# Goal: Exercise Mungo's Buffer-mode abilities


# In order to perform the buffering tests, we need to time each 
# chunk as it arrives.  So, we need response-chunk-handlers, which
#  were added in LWP::UA v 5.827
my $HAVE_LWP_UA_HANDLERS;
BEGIN {
    use LWP::UserAgent;
    $HAVE_LWP_UA_HANDLERS = $LWP::UserAgent::VERSION >= 5.827;

    unless ($HAVE_LWP_UA_HANDLERS) {
        eval "use Test::More skip_all => 'need LWP::UserAgent version 5.827 or newer to test buffering';";
    }
}

use Test::More;


my $test_count = 0;
my %tests = (
             'no-buffer' => {
                             label => "Buffering disabled",
                             pre_fetch => \&reset,
                             get_content => \&get_content,
                             extra_tests => [\&expect_unbuffered],
                             todo => "",
                             #hardskip => 1,
                            },
             'buffer-in-page' => {
                                  label => "Buffering enabled in page",
                                  pre_fetch => \&reset,
                                  get_content => \&get_content,
                                  extra_tests => [\&expect_buffered],
                                  todo => "",
                                  #hardskip => 1,
                                 },
             # Depends on a special LocationMatch declaration in t/conf/extra.conf.in
             'buffer-via-conf' => {
                                   label => "Buffering via conf",
                                   pre_fetch => \&reset,
                                   get_content => \&get_content,
                                   extra_tests => [\&expect_buffered],
                                   todo => "",
                                   #hardskip => 1,
                                  },
             # Depends on a special LocationMatch declaration in t/conf/extra.conf.in
             'unbuffer-override-conf' => {
                                          label => "Buffering enabled conf but overridden in file",
                                          pre_fetch => \&reset,
                                          get_content => \&get_content,
                                          extra_tests => [\&expect_unbuffered],
                                          todo => "",
                                          #hardskip => 1,
                                         },
             'late-headers' => {
                                label => "Sending a late header with buffering",
                                pre_fetch => \&reset,
                                like => qr{mungo-success$},
                                get_content => \&get_content,
                                header => ['X-mungo-test-header', 'ponies'],
                                extra_tests => [\&expect_buffered],
                                todo => "",
                                #hardskip => 1,
                               },
             'late-headers-subinclude' => {
                                           label => "Sending a late header with buffering in a subinclude",
                                           pre_fetch => \&reset,
                                           error_regex => qr{Headers already sent},
                                           get_content => \&get_content,
                                           todo => "",
                                           #hardskip => 1,
                                          },
            );

my @chunk_times;
my $content;

# Install chunk-counter hook
Apache::TestRequest::user_agent()
  ->add_handler(
                response_data => \&record_chunk_timing,
                m_method => 'GET',
               );

perform_page_tests('/17-buffer/', \%tests, \$test_count);
done_testing($test_count);




sub reset {
    $content = '';
    @chunk_times = ();
}

sub get_content { return $content; }

sub record_chunk_timing {
    #my ($chunk, $response, $protocol) = @_;
    my ($response, $ua, $handler, $chunk) = @_;
    push @chunk_times, scalar(gettimeofday());
    $content .= $chunk;
    return 1;
}

sub expect_unbuffered {
    my $info = shift;
    condense_chunks();
    # Should have more than one time-chunk
    ok(@chunk_times > 1, "$info->{label} should arrive in more than one chunk");
    $test_count++;
}

sub expect_buffered {
    my $info = shift;
    condense_chunks();
    # Should have exactly one time-chunk
    ok(@chunk_times == 1, "$info->{label} should arrive in exactly one chunk");
    $test_count++;
}

# Turn LWP::UA data chunks into time-chunks
sub condense_chunks {
    # In seconds. Note that pages wait .5 sec between chunks, so 
    # this is one order of magnitude smaller.
    my $epsilon = 0.05;

    my @buckets;
  CHUNK_TIME:
    foreach my $chunk_time (@chunk_times) {
        # Check to make sure each chunk_time is within epsilon of a bucket time
        # if not, make a new bucket
        my $found_bucket = 0;
      BUCKET:
        foreach my $bucket (@buckets) {
            if ($bucket - $epsilon < $chunk_time && $chunk_time < $bucket + $epsilon) {
                $found_bucket = 1; # happy lolrus
                next CHUNK_TIME;
            }
        }

        # Must not have found an appropriate bucket - make one
        push @buckets, $chunk_time;
    }

    # OK, swap out the chunk_times with the condensed version
    @chunk_times = @buckets;

}
