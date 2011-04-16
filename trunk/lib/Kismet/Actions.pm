package Kismet::Actions;

use Data::Dumper;

# Actions are everything a player can do.  All should be listed in this file.  All functions should accept
#
# actor - the character initiating the action
# command_args - anything else sent on the command line as an arg from the browser

our %action_list;

sub enter_world {
    my ($acting_char, $arg_string) = @_;

}

BEGIN {
    $action_list{'enter_world'} = \&enter_world;
}

1;
