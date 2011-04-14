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

for (qw/exitid roomid direction destination/) {
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
