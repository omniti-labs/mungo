package Kismet::Room;

use Kismet::Object;
use Kismet::Comm;
use Kismet::DB;

my @ISA = qw/Kismet::Object/;

sub new {
    my $self = shift;
    my $class = ref($self) || $self;
    $self = bless {}, $class;
    my $arg = shift;
    if( $arg ) {
        return $self->loadFromHashRef( $arg ) if ref $arg;
        return $self->loadFromId( $arg );
    }
    return $self;
}

sub loadFromId {
    my $self = shift;

    # TODO - load from database id
}

sub loadFromHashRef {
    my $self = shift;
    my $href = shift;
    $self = bless $href, ref($self);
    return $self;
}

# THIS IS A STATIC FUNCTION
sub loadAllRooms {
    my $self = shift;
    my %rooms;

    my $dbh = Kismet::DB->new();
    my $sth = $dbh->prepare('select * from world.rooms');
    $sth->execute();
    while( my $href = $sth->fetchrow_hashref() ) {
        my $room = Kismet::Room->new( $href );
        next if !$room;
        $rooms{ $room->roomid() } = $room;
    }
    return \%rooms;
}

sub addExit {
    my $self = shift;
    my $exit = shift;
    if( exists $self->{exits}->{$exit->direction()} ) {
        print STDERR "WARNING - duplicate exit for a room.\n" . Dumper( $self ) . Dumper( $exit );
        return;
    }
    $self->{exits}->{$exit->direction()} = $exit;
}

sub getExit {
    my $self = shift;
    my $direction = shift;

    return undef if !$self->{exits} || !$self->{exits}->{$direction};
    return $self->{exits}->{$direction};
}

sub addToRoom {
    my $self = shift;
    my $thing = shift;
    my $preference = shift;

    my $rand;
    $rand = rand() if !$preference;
    if( $preference eq "left" || $rand < .5 ) {
        push @{$self->{left}}, $thing;
        return "left";
    } else {
        push @{$self->{right}}, $thing;
        return "right";
    }
}

sub playerEnter {
    my $self = shift;
    my $player = shift;
    my $arrival_dir = shift;

    my $side = $self->addToRoom( $player );
    # TODO - send the entered room data to the player and graphically move their icon in

    # TODO - notify the room that he arrived
    Kismet::Comm::notify("%c %t in from the $arrival_dir.", ( actor => $player, type => 'TO_ROOM' ) );
    # TODO - graphically update the room with the players arrival
}

sub playerLeave {
    my $self = shift;
    my $player = shift;
    my $destination = shift;
    
    # TODO - graphically update the user with the leave

    # TODO - notify the room that he left
    Kismet::Comm::notify("%c %t " . $destination->direction . ".", ( actor => $player, type => 'TO_ROOM' ) );
    $self->removeFromRoom( $player );
}

sub removeFromRoom {
    my $self = shift;
    my $thing = shift;

    # remove thing from left and right
    # TODO - splice?  
    die "removeFromRoom not yet implemented";
}

sub get_players {
    my $self = shift;
    my $side = shift;

    return @{ $self->{left} } if $side eq "left";
    return @{ $self->{right} } if $side eq "right";
    return ( @{ $self->{left} }, @{ $self->{right} } ); # both sides
}

for (qw/roomid title description/) {
    my $attr = uc($_);
    eval "sub $_ {
            my \$self = shift;
            if( \@_ ) {
              \$self->{\$attr} = shift;
            }
            \$self->{$attr};
        };";
}

1;
