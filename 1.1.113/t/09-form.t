# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use lib './t/lib';
use lib '../t/lib';
use MungoTestUtils;


use Apache::Test qw();
use Apache::TestRequest qw(GET POST);
use Test::More import => [qw(is ok is_deeply)];


# 09-form.t
# Goal: Exercise Mungo's form handling abilities
#       Uploads are tested under 10-upload

=for page list

Note:
default = no enctype specified
axfwe = application/x-www-form-urlencoded
mpfd = multipart/form-data

empty-axwfu
empty-mpfd
string-axwfu
string-mpfd
empty-string-axwfu
empty-string-mpfd
integer-axwfu
integer-mpfd
escaped-string-axwfu
escaped-string-mpfd
two-axwfu
two-mpfd
repeated-axwfu
repeated-mpfd

form-post-dumper-echo - echos $Request->Form() as Dumper output (action of all forms)

=cut

my %tests;
my $test_count;

BEGIN {
    %tests = (
              'empty'  => {
                           form_spec => {
                                         form_number => 1,
                                        },
                           expected => {},
                          },
              'string' => {
                           form_spec => {
                                         with_fields => {
                                                         foo => 'bar',
                                                        },
                                        },
                           expected => {
                                        foo => 'bar',
                                       },
                          },
              'empty-string' => {
                                 form_spec => {
                                               with_fields => {
                                                               foo => '',
                                                              },
                                              },
                                 expected => {
                                              foo => '',
                                             },
                                },
              'integer' => {
                            form_spec => {
                                          with_fields => {
                                                          foo => 1,
                                                         },
                                         },
                            expected => {
                                         foo => 1,
                                        },
                           },
              'unescaped-string' => {
                                     form_spec => {
                                                   with_fields => {
                                                                   foo => 'I am the very model of a modern major general',
                                                                  },
                                                  },
                                     expected => {
                                                  foo => 'I am the very model of a modern major general',
                                                 },
                                    },
              'escaped-string' => {
                                     form_spec => {
                                                   with_fields => {
                                                                   foo => 'kittehs%20and%20ponies',
                                                                  },
                                                  },
                                     expected => {
                                                  foo => 'kittehs%20and%20ponies',
                                                 },
                                    },
              'two' => {
                        form_spec => {
                                      with_fields => {
                                                      foo => '1',
                                                      bar => '2',
                                                     },
                                     },
                        expected => {
                                     foo => 1,
                                     bar => 2,
                                    },
                       },
              'repeated' => {
                             form_spec => {
                                           multi => 1,
                                           fields => [['foo', 1, 1], ['foo', 2, 2]],
                                          },
                             expected => {
                                          foo => [1,2],
                                         },
                            },
             );

    $test_count = 3*4*(scalar keys %tests);
}

use Test::More tests => $test_count;

my $mech = make_mech();

foreach my $ct (qw(default axwfu mpfd)) {
#foreach my $ct (qw(axwfu)) {
    foreach my $test_name (sort keys %tests) {
        my $url = '/09-form/' . $test_name . '-' . $ct . '.asp';

        # Fetch form
        $mech->get_ok($url, "Fetch of $url should be OK");

        # Submit form
        my $spec = $tests{$test_name}{form_spec};
        my $expected = $tests{$test_name}{expected};
        my $response;
        if ($spec->{multi}) {
            $mech->form_number(1);
            foreach my $field (@{$spec->{fields}}) {
                $mech->field(@$field);
            }
            $response = $mech->submit();
        } else {
            $response = $mech->submit_form(%$spec);
        }

        is($response->code, 200, "Submit to post-echo should be HTTP status 200");
        my $content = $response->content();
        my $form;
        eval $content;
        ok(!$@, "Evalling the return hould not throw an error - got $@");
        is_deeply($form, $expected, "Results should be correct, test $test_name, mode $ct");
    }
}
