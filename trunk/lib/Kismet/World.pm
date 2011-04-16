package Kismet::World;

use Kismet::Room;
use Kismet::Exit;

use Kismet::Object;
my @ISA = qw/Kismet::Object/;

use Data::Dumper;

sub new {
    my $self = shift;
    my $class = ref($self) || $self;
    $self = bless {}, $class;
    $self->loadAll();
    return $self;
}

sub loadAll() {
    my $self = shift;
    $self->loadObjects();
    $self->loadMobs();
    $self->loadRooms();
}

sub loadObjects() {
    my $self = shift;
    # TODO
}

sub loadMobs() {
    my $self = shift;
    # TODO
}

sub loadRooms() {
    my $self = shift;
    
    $self->{rooms} = Kismet::Room->loadAllRooms();
    Kismet::Exit->loadAllExits( $self );
}

sub room {
    my $self = shift;
    my $roomid = shift;
    return $self->{rooms}->{ $roomid } if defined $self->{rooms}->{ $roomid };
    return undef;
}

sub character {
    my $self = shift;
    my $char_string = shift;

    if( $char_string =~ /^\d+$/ ) {
        return $self->{characters_by_id}->{$char_string} if $self->{characters_by_id}->{$char_string};
        my $loaded = Kismet::Player->loadFromId( $char_string );
        return undef if !$loaded;
        $self->{characters_by_id}->{$char_string} = $loaded;
        $self->{characters_by_name}->{$loaded->name} = $loaded;
        return $loaded;
    }
    return $self->{characters_by_name}->{$char_string} if $self->{characters_by_name}->{$char_string};
    my $loaded = Kismet::Player->new( $char_string );
    return undef if !$loaded;
    $self->{characters_by_id}->{$loaded->characterid} = $loaded;
    $self->{characters_by_name}->{$char_string} = $loaded;
    return $loaded;
}

1;
