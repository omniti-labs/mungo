package MungoTestUtils;
use strict;
use warnings FATAL => 'all';

use base 'Exporter';
our @EXPORT = ();


use Apache::Test qw();
use Apache::TestRequest qw(GET);
use Test::More import => [qw(is ok like unlike $TODO)];
use Test::WWW::Mechanize qw();
use Data::Dumper;


=head2 perform_page_tests('/01-foo/', \%tests);

Performs 4 tests for each page, by fetching the page and checking the HTTP status (1 test), comparing the page contents to a regex (! test ) and checking to ensure no Mungo tags are present (2 tests).

%tests should have keys that are pages under the base (.asp will be appended).  
Values may be either strings or hashrefs.  If a string, it is taken to be the regex 
against which to match the page.  If a hashref, these keys are available:

=over

=item like

Regex to match against the page content.

=item status

HTTP status code, default 200.

=item todo

Boolean.  If true, this page's tests are marked TODO.

=item query

String, staring with '?'.  Will be appended as query string.

=back

=cut

push @EXPORT, 'perform_page_tests';
sub perform_page_tests {
    my $base = shift;
    my $tests = shift;

    foreach my $test_page (sort keys %$tests) { # Sort is so the order is repeatable
        my $info = $tests->{$test_page};
        unless (ref($info) eq 'HASH') {
            $info = { like => $info };
        }
        $info->{page} = $test_page;
        $info->{base} = $base;

        my $todo    = $info->{todo} || 0;

        if ($todo) {
          TODO: {
                local $TODO = $todo;
                do_one_page_test($info);
            }
        } else {
            do_one_page_test($info);
        }
    }
}
sub do_one_page_test {
    my $info = shift;
    my $qs      = $info->{query} || '';
    my $status  = $info->{status} || 200;
    my $pattern = $info->{like};
    my $page    = $info->{page};

    my $url = $info->{base} . $page . '.asp' . $qs;
    my $response = GET $url;
    is($response->code, $status, "Fetch of $url should be HTTP status $status");
    my $content = $response->content();
    like($content, $pattern, "Content of $url should be correct");
    unlike($content, qr{<\%}, "$url should not contain mungo start tag '<\%'");
    unlike($content, qr{\%>}, "$url should not contain mungo end tag '\%>'");
}

=head2 $str = get_url_base();

Returns a string like 'http://localhost:8529', on which
the test server is running.

=cut

push @EXPORT, 'get_url_base';
sub get_url_base {
    my $cfg = Apache::Test::config();
    #print Dumper($cfg);
    my $url = $cfg->{vars}->{scheme} 
      . '://'
        . $cfg->{vars}->{remote_addr}
          . ':'
            . $cfg->{vars}->{port};

    return $url;
}

=head2 $mech = make_mech();

Creates and returns a Test::WWW::Mechanize object.  It will be primed with the
base URL to be that of the test server.

=cut

push @EXPORT, 'make_mech';
sub make_mech {
    my $mech = Test::WWW::Mechanize->new
      (
       cookie_jar => {},  # enable cookies
       max_redirect => 0, # don't automatically follow redirects
      );

    # Do one fetch to set the internal URL base
    $mech->get(get_url_base);

    return $mech;
}


1;
