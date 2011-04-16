package Kismet::Player;

use Kismet::Object;
use Cache::Memcached;

my @ISA = qw/Kismet::Object/;

my %g_player_list;  # List of players currently in the world - used by server

sub new {
    my $self = shift;
    my $class = ref($self) || $self;
    my $arg = shift;
    if( $arg ) {
        return Kismet::Player::loadFromId( $arg ) if $arg =~ /^\d+$/;
        return Kismet::Player::loadFromName( $arg );
    }
    $self = bless {}, $class;
    return $self;
}

sub loadFromName {
    my $self = shift;
    my $name = shift;

    my $dbh = Kismet::DB->new();
    my $sth = $dbh->prepare('select * from system.characters where name = ?');
    $sth->execute( $name );
    my $href = $sth->fetchrow_hashref();
    $sth->finish;

    return undef if !$href;
    return bless $href, 'Kismet::Player';
}

sub loadFromId {
    my $self = shift;
    my $id = shift;

    my $dbh = Kismet::DB->new();
    my $sth = $dbh->prepare('select * from system.characters where characterid = ?');
    $sth->execute( $id );
    my $href = $sth->fetchrow_hashref();
    $sth->finish;

    return undef if !$href;
    return bless $href, 'Kismet::Player';
}

sub canMove {
    my $self = shift;
    # TODO - return false if DEAD or fighting or cannot move for some other reason
    return 1;
}

sub in_room {
    my $self = shift;
    my $new_room = shift;

    die("Non-room object passed to Player->in_room()\n".Dumper($new_room).Dumper($self)) 
        if $new_room && ref $new_room ne "Kismet::Room";
    $self->{in_room} = $new_room if $new_room;
    return $self->{in_room};
}

# Sends raw data (which should already be in JSON format) to Memcached so that it will get served to the browser on it's next request
sub send_to_browser {
    my $self = shift;
    my $data = shift;
    my $cache = Cache::Memcached->new();

    my $key = "out_q_" . $self->playerid;
    return $cache->append($key, $data);
}

# Send a message to the user
sub notify {
    my $self = shift;
    my $message = shift;
    my $obj = { raw_message => $message };
    # TODO - actually send to user
}

sub get_possessive {
    my $self = shift;
    return "his" if $self->{sex} = 'm';
    return "her" if $self->{sex} = 'f';
    return "its";
}

sub get_pronoun {
    my $self = shift;
    return "him" if $self->{sex} = 'm';
    return "her" if $self->{sex} = 'f';
    return "it";
}

sub get_travel_type {
    # return "flies" if $self->{FLYING};
    # return "stumbles" if ....
    # return "rides" if ....
    return "walks";
}

sub get_side {
    my $self = shift;

    # TODO
}

for (qw/characterid name accountid/) {
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
