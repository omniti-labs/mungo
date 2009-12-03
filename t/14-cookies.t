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

# 14-cookies.t
# Goal: Exercise Mungo's cookie setting, reading, and clearing

=for page list

set-cookie

=for example output

mungo-success (mungo-test-cookie)

=cut

my $test_count = 0;
my %tests = (
             # Order is important - test names are in order
             '01-set-cookie' => {
                                 label => "Set a cookie",
                                 page => 'set-cookie',
                                 like => qr{^\nmungo-success$},
                                 extra_tests => [ \&set_cookie_check ],
                                 todo => "",
                                 #hardskip => 1,
                                },
             '02-read-cookie' => {
                                  label => "Read a cookie server-side",
                                  page => 'dump-cookies',
                                  eval_dump => {
                                                mungocookie1 => { Value => 'ponies' },
                                               },
                                  todo => "",
                                  #hardskip => 1,
                                 },
             '03-clear-cookie' => {
                                   label => "Set a cookie",
                                   page => 'clear-cookie',
                                   like => qr{^\nmungo-success$},
                                   extra_tests => [ \&clear_cookie_check ],
                                   todo => "",
                                   #hardskip => 1,
                                  },
             '04-set-multivalue' => {
                                     label => "Set a multi-valued cookie",
                                     page => 'set-multivalue',
                                     like => qr{^\nmungo-success$},
                                     extra_tests => [ \&set_multi_check ],
                                     todo => "",
                                     #hardskip => 1,
                                    },
             '05-read-multivalue' => {
                                      label => "Read a multivalued cookie server-side",
                                      page => 'dump-cookies',
                                      eval_dump => {
                                                    mungocookie2 => {
                                                                     Value => {
                                                                               horned => 'unicorns',
                                                                               hornless => 'ponies',
                                                                              },
                                                                    },
                                                   },
                                      todo => "",
                                      #hardskip => 1,
                                    },
            );

# Setup Apache::TestRequest to use a UA that remembers cookies
my $cookie_jar = HTTP::Cookies->new();
Apache::TestRequest::user_agent(reset => 1, cookie_jar => $cookie_jar);

perform_page_tests('/14-cookies/', \%tests, \$test_count);
done_testing($test_count);

sub set_multi_check {
    my ($info, $response, $test_count_ref) = @_;
    # $cookie_jar should have been updated
    my $label = $info->{label};

    is(cj_count_cookies($cookie_jar), 1, "$label should result in exactly 1 cookie set");
    $$test_count_ref++;

    my %cookie = cj_extract_cookie($cookie_jar, 'mungocookie2');
    is($cookie{name}, 'mungocookie2', "$label should result in the right cookie being set");
    $$test_count_ref++;

    my %expected = (
                    horned => 'unicorns',
                    hornless => 'ponies',
                   );
    my %got = map {split('=', $_)} split('&', $cookie{value});

    is_deeply(\%got, \%expected, "$label should result in the right cookie value");
    $$test_count_ref++;
}


sub set_cookie_check {
    my ($info, $response, $test_count_ref) = @_;
    # $cookie_jar should have been updated
    my $label = $info->{label};

    is(cj_count_cookies($cookie_jar), 1, "$label should result in exactly 1 cookie set");
    $$test_count_ref++;

    my %cookie = cj_extract_cookie($cookie_jar, 'mungocookie1');
    is($cookie{name}, 'mungocookie1', "$label should result in the right cookie being set");
    $$test_count_ref++;

    is($cookie{value}, 'ponies', "$label should result in the right cookie value");
    $$test_count_ref++;
}

sub clear_cookie_check {
    my ($info, $response, $test_count_ref) = @_;
    # $cookie_jar should have been updated
    my $label = $info->{label};

    is(cj_count_cookies($cookie_jar), 0, "$label should result in exactly 0 cookies set");
    $$test_count_ref++;

}


#=======================================================#
#                 Cookie Jar Utilities
#    (HTTP::Cookies has a horrid interface for reading)
#=======================================================#


sub cj_count_cookies {
    my $cj = shift;
    my $count = 0;
    $cj->scan(sub {
                  $count++;
              });
    return $count;
}

sub cj_extract_cookie {
    my $cj = shift;
    my $seek_name = shift;
    my %cookie;
    my $found = 0;
    $cj->scan(
              sub {
                  return if $found;
                  my @fields = qw(version name value path domain port path_spec secure expires discard hash);
                  if ($_[1] eq $seek_name) {
                      @cookie{@fields} = @_;
                      $found = 1;
                  }
              }
             );
    return %cookie;
}
