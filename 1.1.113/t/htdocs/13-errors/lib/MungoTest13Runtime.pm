package MungoTest13Runtime;
use strict;
use warnings;
use base 'Exporter';
use Carp qw(croak);
our @EXPORT;

=pod

Marker text to indicate that the source of the test module is displayed.

=cut

push @EXPORT, 'die_in_module';
sub die_in_module {
    die "Dying within MungoTest13Runtime::die_in_module";
}

push @EXPORT, 'croak_in_module';
sub croak_in_module {
    croak("Croaking within MungoTest13Runtime::croak_in_module");
}



1;
