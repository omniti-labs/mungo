# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use Apache::Test qw();
use Apache::TestRequest qw(GET);

use lib './t/lib';
use lib '../t/lib';
use MungoTestUtils;
use Test::More;

# 13-errors.t - lucky 13
# Goal: What could possiblie goe rong?

=for page list

preceding-text.asp
within-loop
no-following-text.asp
extra-header.asp

=for example output

mungo-success

=cut

my $test_count = 0;
my %tests = (

             'catch-exception' => {
                                   label => "Catching a die",
                                   status => 200,
                                   like => qr{^mungo-success\n\n$},
                                   todo => "",
                                   #hardskip => 1,
                                  },
             'compile-syntax' => {
                                  label => "Basic syntax error",
                                  status => 500,
                                  error_regex => qr{syntax error},
                                  unlike => qr{mungo-failure},
                                  #hardskip => 1,
                                 },
             'compile-use' => {
                               label => "Bad use statement",
                               status => 500,
                               error_regex => qr{Can\'t locate No/Such/Module\.pm in \@INC},
                               unlike => qr{mungo-failure},
                               #hardskip => 1,
                              },
             'compile-stricture' => {
                                     label => "Stricture violation",
                                     status => 500,
                                     error_regex => qr{Global symbol .* requires explicit package name},
                                     unlike => qr{mungo-failure},
                                     #hardskip => 1,
                                    },
             'strict-by-default' => {
                                     label => "Strictures should be enabled by default",
                                     status => 500,
                                     error_regex => qr{Global symbol .* requires explicit package name},
                                     unlike => qr{mungo-failure},
                                     #hardskip => 1,
                                    },
             'runtime-method-on-unblessed' => {
                                               label => "Runtime error via method call on unblessed ref",
                                               status => 500,
                                               error_regex => qr{Can\'t call method .* on unblessed},
                                               like => qr{^mungo-success\n},
                                               unlike => qr{mungo-failure},
                                               #hardskip => 1,
                                              },
             'runtime-die-in-package' => {
                                          label => "Runtime die within a custom loaded module",
                                          status => 500,
                                          # According to the Mungo docs and previous trac tickets like trac3
                                          # this should dump the module source
                                          error_regex => qr{Dying within MungoTest13Runtime::die_in_module.*Marker text to indicate that the source of the test module is displayed},
                                          like => qr{^mungo-success\n},
                                          unlike => qr{mungo-failure},
                                          todo => "Awaiting fix on trac21",
                                          #hardskip => 1,
                                         },
             'compile-use-source-dump' => {
                                           label => "Attempt to use module that won't compile",
                                           status => 500,
                                           error_regex => qr{package MungoTest13WontCompile.*Marker text to indicate that the source of the test module is displayed},
                                           unlike => qr{mungo-failure},
                                           todo => "Awaiting fix on trac21",
                                           #hardskip => 1,
                                          },
             'runtime-croak-in-package' => {
                                            label => "Runtime croak within a custom loaded module",
                                            status => 500,
                                            # This should either dump the module source or the ASP page
                                            error_regex => qr{Dying within MungoTest13Runtime::croak_in_module.*Marker text to indicate that the source of the test module is displayed},
                                            like => qr{^mungo-success\n},
                                            unlike => qr{mungo-failure},
                                            todo => "Awaiting fix on trac19",
                                           },
            );


perform_page_tests('/13-errors/', \%tests, \$test_count);
done_testing($test_count);


