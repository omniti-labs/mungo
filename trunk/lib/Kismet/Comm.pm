package Kismet::Comm;

# Communication package for notifying players of data that needs to be sent to them.  Also makes the determination
# of if the player is able to see that data and needs to be notified of it or not.

# Message Macros:
# %c/%C - acting/victim character's name
# %s/%S - acting/victim possessive (his/her/its)
# %m/%M - active/victim pronoun (him/her/it)
# %t/%T - active/bictim travel type (walk, fly, ride, etc)

# Arguments:
# actor - Player object (required except for TO_ROOM with a room specified)
# room - Override actor's room in TO_ROOM types
# victim - Player object
# json - raw JSON to pass onto everyone that gets the message
# type - determines who gets the message - REQUIRED
#    TO_ROOM - send to everyone in the room
#    TO_SIDE - send to everyone on actor's side of the room
#    TO_ZONE - send to everyone in the actor's zone
#    TO_WORLD - send to world
#    TO_VICT - send to victim
# vis_only - only send the message to people that can see it (never show "someone")

# Passed a macro'd message string along with a hash of arguments used to determine the type of messaging and the data to populate it
sub notify {
    my $self = shift;  # TODO - needed?
    my $orig_message = shift;
    my %args = @_;

    if( !$args{type} ) {
        print STDERR "No type sent to Comm::notify()";
        return;
    }

    # Determine everyone that gets sent the message based on the arg "type"
    my @targets;
    if( $args{type} eq "TO_SIDE" ) {
        my $dest_room;
        $dest_room ||= $args{actor}->in_room() if $args{actor};
        if( !$dest_room ) {
            print STDERR "No valid room in Comm::notify() (side)";
            return;
        }
        @targets = $dest_room->get_players( $args{actor}->get_side() );
    }
    if( $args{type} eq "TO_ROOM" ) {
        my $dest_room;
        $dest_room = $args{room};
        $dest_room ||= $args{actor}->in_room() if $args{actor};
        if( !$dest_room ) {
            print STDERR "No valid room in Comm::notify() (room)";
            return;
        }
        @targets = $dest_room->get_players();
    }
    if( $args{type} eq "TO_ZONE" ) {
        # TODO
        print STDERR "notify TO_ZONE not implemented yet";
    }
    if( $args{type} eq "TO_WORLD" ) {
        # TODO
        print STDERR "notify TO_WORLD not implemented yet";
    }
    if( $args{type} eq "TO_WORLD" ) {
        return if !$args{victim} || 'Kismet::Player' ne ref $args{victim};
        push @targets, $args{victim};
    }
    else {
        # Don't send message to actor or victim
        @targets = grep { $_ != $args{actor} && $_ != $args{victim} } @targets;
    }
    return if !scalar @targets; # No one to send to!

    foreach my $target (@targets) {
        my $message = $orig_message;
        if( $args{actor} ) {
            my ($name, $pass, $pron, $travel) = Kismet::Comm::__replace_macros( $args{actor}, $target );
            $message =~ s/%c/$name/g;
            $message =~ s/%s/$poss/g;
            $message =~ s/%m/$pron/g;
            $message =~ s/%t/$travel/g;
        }
        if( $args{victim} ) {
            my ($name, $pass, $pron, $travel) = Kismet::Comm::__replace_macros( $args{victim}, $target );
            $message =~ s/%C/$name/g;
            $message =~ s/%S/$poss/g;
            $message =~ s/%M/$pron/g;
            $message =~ s/%T/$travel/g;
        }
        # TODO - uppercase first character in the message unless passed a flag not to

        next if $args{vis_only} && !$target->canSee( $actor );
        $target->notify( $message );
        $target->send_to_browser( $args{json} ) if $args{json};
    }
}

sub __replace_macros {
    my $self = shift; ## TODO - needed?
    my $player = shift;
    my $viewer = shift;

    my $name = $viewer->can_see( $player ) ? $player->name() : "someone";
    my $poss = $viewer->can_see( $player ) ? $player->get_possessive() : "its";
    my $pron = $viewer->can_see( $player ) ? $player->get_pronoun() : "it";
    my $trav = $viewer->can_see( $player ) ? $player->get_travel_type() : "moves";
    return $name, $pass, $pron, $trav;
}

1;
