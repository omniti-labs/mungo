# -*-cperl-*-
use strict;
use warnings;
no warnings 'redefine';

my %modules;
BEGIN {
    # Module name => minimum version
    %modules = (
                'Apache::Test' => '',
                'mod_perl2' => '',
               );
}

use Test::More tests => (scalar keys %modules);

foreach my $module (keys %modules) {
    my $version = $modules{$module};
    if ($version) {
        use_ok($module, $version);
    } else {
        use_ok($module);
    }
}
