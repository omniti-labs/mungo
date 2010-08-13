# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use Apache::Test qw();
use Apache::TestRequest qw(GET POST);
use Test::More import => [qw(is ok is_deeply)];

# 08-query.t
# Goal: Exercise Mungo's querystring parsing abilities

=for page list

dumper-echo

=for example output



=cut

my %tests;
my $test_count;

BEGIN {
    %tests = (
              'empty'  => {
                           query => '',
                           expected => {},
                          },
              'string'  => {
                            query => 'foo=bar',
                            expected => { foo => 'bar' },
                           },
              'empty-string'  => {
                                  query => 'foo=',
                                  expected => { foo => '' },
                                 },
              'integer'  => {
                             query => 'foo=1',
                             expected => { foo => 1 },
                            },
              'unescaped-string'  => {
                                      query => 'foo=I am the very model of a modern major general',
                                      expected => { foo => 'I am the very model of a modern major general' },
                                     },
              'escaped-string'    => {
                                      query => 'foo=kittehs%20and%20ponies',
                                      expected => { foo => 'kittehs and ponies' },
                                     },
              'two' => {
                        query => 'foo=1&bar=2',
                        expected => { foo => 1, bar => 2 },
                       },
              'repeated' => {
                             query => 'foo=1&foo=2',
                             expected => { foo => [1,2]},
                            },
             );
    $test_count = 12*(scalar keys %tests);
}

use Test::More tests => $test_count;

foreach my $method (qw(GET POST)) {
    foreach my $ct (qw(application/x-www-form-urlencoded multipart/form-data)) {
        foreach my $test_name (sort keys %tests) {
            my $query = $tests{$test_name}{query};
            my $expected = $tests{$test_name}{expected};

            my $url = '/08-query/dumper-echo.asp?' . $query;
            my $response = $method eq 'GET' ? 
              GET($url, 'Content-Type' => $ct) :
                POST($url, 'Content-Type' => $ct);

            is($response->code, 200, "Fetch of $url should be HTTP status 200");
            my $content = $response->content();
            my $qs;
            eval $content;
            ok(!$@, "Evalling the return hould not throw an error - got $@");
            is_deeply($qs, $expected, "Results should be as expected");
        }
    }
}
