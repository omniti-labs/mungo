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

1;
