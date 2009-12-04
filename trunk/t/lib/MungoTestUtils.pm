package MungoTestUtils;
use strict;
use warnings FATAL => 'all';

use base 'Exporter';
our @EXPORT = ();


use Apache::Test qw();
use Apache::TestRequest qw(GET);
use Apache::TestUtil qw(t_start_error_log_watch t_finish_error_log_watch t_client_log_error_is_expected);
use Test::More import => [qw(is ok like unlike $TODO is_deeply)];
use Test::WWW::Mechanize qw();
use File::Temp qw(tempfile);


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
    my $test_count_ref = shift;

    foreach my $test_page (sort keys %$tests) { # Sort is so the order is repeatable
        my $info = $tests->{$test_page};
        unless (ref($info) eq 'HASH') {
            $info = { like => $info };
        }
        next if $info->{hardskip};
        $info->{page} ||= $test_page;
        $info->{base} = $base;
        $info->{label} ||= $test_page;
        $info->{status} ||= 200;

        my $todo    = $info->{todo} || 0;

        if ($todo) {
          TODO: {
                local $TODO = $todo;
                do_one_page_test($info, $test_count_ref);
            }
        } else {
            do_one_page_test($info, $test_count_ref);
        }
    }
}
sub do_one_page_test {
    my $info = shift;
    my $test_count_ref = shift;
    my $qs      = $info->{query} || '';
    my $page    = $info->{page};
    my $label   = $info->{label};

    my $url = $info->{base} . $page . '.asp' . $qs;
    my %opts = %{$info->{request_options} || {}};

    if ($info->{pre_fetch}) {
        $info->{pre_fetch}->($info);
    }

    if ($info->{error_log_scanner}) {
        t_client_log_error_is_expected();
        t_start_error_log_watch();
    }
    my $response = GET $url, %opts;
    if ($info->{error_log_scanner}) {
        my @entries = t_finish_error_log_watch();
        $info->{error_log_scanner}->($info, @entries);
    }

  TODO: {
        local $TODO = $info->{status} == 500 ? 'awaiting fix on trac17' : $TODO;
        is($response->code, $info->{status}, "$label should have HTTP status $info->{status}");
        $$test_count_ref++;
    }

    # Header check
    if ($info->{header}) {
        my ($name, $value) = @{$info->{header}};
        my $saw = $response->header($name);
        is($saw, $value, "$label should have header value on response");
        $$test_count_ref++;
    }

    # Content Checks
    my $content;
    if ($info->{get_content}) {
        $content = $info->{get_content}->();
    } else {
        $content = $response->content();
    }
    if ($info->{like}) {
        like($content, $info->{like}, "$label should have correct content");
        $$test_count_ref++;
    }
    if ($info->{unlike}) {
        unlike($content, $info->{unlike}, "$label should not have incorrect content");
        $$test_count_ref++;
    }
    unlike($content, qr{(<\%)|(\%>)}, "$label should not contain mungo start or end tags ");
    $$test_count_ref++;

    # Did an error occur?
    if ($info->{error_regex}) {
        like($content, $info->{error_regex}, "$label should be a Mungo error with the correct content");
        $$test_count_ref++;
    } else {
        # No error should have occurred.
        unlike($content, qr{Error in Include}, "$label should not appear to be a Mungo Include Error");
        $$test_count_ref++;
    }

    # Eval-Dumper Test
    if ($info->{eval_dump}) {
        my $expected = $info->{eval_dump};
        my $got;
        eval $content;
        is($@, '', "$label should eval its response without error");
        $$test_count_ref++;

        is_deeply($got, $expected, "$label should have the correct dumpered data");
        $$test_count_ref++;
    }

    # Permit custom hooks, too
    $info->{extra_tests} ||= [];
    $info->{extra_tests} = ref($info->{extra_tests}) eq 'ARRAY' ? $info->{extra_tests} : [ $info->{extra_tests} ];
    foreach my $extra_test_hook (@{$info->{extra_tests}}) {
        $extra_test_hook->($info, $response, $test_count_ref);
    }
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

=head2 $path = make_dummy_file($size_in_bytes, $binary);

Makes a file filled with random numbers.  Returns the absolute path to the file.

=cut

push @EXPORT, 'make_dummy_file';
sub make_dummy_file {
    my $desired_size = shift;
    my $binary = shift || 0;
    my $handle = File::Temp->new(UNLINK => 0); # Set to 0 to leave the file hanging around
    #my $handle = File::Temp->new(UNLINK => 1);
    my $name = $handle->filename();

    unless ($desired_size) {
        close $handle;
        return $name;
    }
    my $begin = "BEGIN MARKER\n";
    my $begin_length = length($begin);
    my $end = "END MARKER\n";
    $desired_size = $desired_size - length($begin) - length($end);
    print $handle $begin;
    if ($binary) {
        $desired_size--; # Needed because echo will add a newline before and after
        close $handle;
        system("/bin/dd if=/dev/urandom of=$name count=$desired_size bs=1 seek=$begin_length conv=fsync status=noxfer 2> /dev/null");
        system("/bin/echo '$end' >> $name");
    } else {
        my $remaining = $desired_size;
        while ($remaining >= 10240) {
            print $handle ('X' x 10239) . "\n";
            $remaining -= 10240;
        }
        print $handle 'X' x $remaining;
        print $handle $end;
        close $handle;
    }

    return $name;
}

1;
