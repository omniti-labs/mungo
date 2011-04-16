package Kismet::Exit;

use Kismet::Object;
use Kismet::Room;

my @ISA = qw/Kismet::Object/;

sub new {
    my $self = shift;
    my $class = ref($self) || $self;
    $self = bless {}, $class;
    return $self->loadFromHashRef( @_ ) if @_;
    return $self;
}

sub loadFromHashRef {
    my $self = shift;
    my $class = ref($self) || $self;
    my $href = shift;
    my $world = shift;

    $self = bless $href, $class;

    if( !$world->room( $self->roomid() ) ) {
        print STDERR "Exit without a room : " . Dumper( $self );
        return undef;
    }
    if( !$world->room( $self->destination() ) ) {
        print STDERR "Exit without a destination : " . Dumper( $self );
        return undef;
    }

    $self->{destination} = $world->room( $self->destination() );

    return $self;
}

# THIS IS A STATIC FUNCTION
# must be passed the world object
sub loadAllExits {
    my $self = shift;
    my $world = shift;

    my $dbh = Kismet::DB->new();
    my $sth = $dbh->prepare('select * from world.exits');
    $sth->execute();
    while( my $href = $sth->fetchrow_hashref() ) {
        my $exit = Kismet::Exit->loadFromHashRef( $href, $world );
        next if !$exit;
        $world->room( $exit->roomid() )->addExit( $exit );
    }
}

sub destination {
    my $self = shift;
    return $self->{destination};
}

# Go through the exit to enter the next room
# Passed a Player object
sub enter {
    my $self = shift;
    my $player = shift;

    $player->in_room()->playerLeave( $player, $self->destination() );
    $player->in_room( $self->destination() );
    $self->destination()-playerEnter( $player );
    return;
}

sub JSONObj {
    my $self = shift;
    my $response = { name => $self->direction };
    my $text = $self->direction;
    $text = '&dArr;' if $text eq 'south';
    $text = '&uArr;' if $text eq 'north';
    $text = '&rArr;' if $text eq 'east';
    $text = '&lArr;' if $text eq 'west';
    $response->{text} = $text;
    $response->{icon} = $self->icon if $self->icon;
    my $class;
    $class = 'dir_north' if $self->direction eq 'north';
    $class = 'dir_south' if $self->direction eq 'south';
    $class = 'dir_east'  if $self->direction eq 'east';
    $class = 'dir_west'  if $self->direction eq 'west';
    $response->{loc}->{class} = $class if $class;
    # TODO - loc - style - needs storage/member var too - this is for specifying location for non-standard dirs

    return $response;
}

# TODO - style
for (qw/exitid roomid direction destination icon/) {
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
