package Kismet::Cmd;

# This package is a wrapper for commands coming from the clients to get queue'd for processing
# and for the game server to request commands to process. 

# For now, this is being done with a database queue
# TODO - this needs to get replaced with a queuing system like RabbitMQ

use Kismet::DB;
use List::Util qw(shuffle);

our $CMD_TYPE_SERVER = 1;
our $CMD_TYPE_IMMEDIATE = 2;
our $CMD_TYPE_COMBAT = 3;
our $CMD_TYPE_MOVEMENT = 4;

sub pushCommand {
    my $command = shift;
    my $type = shift;
    my $character = shift;

    die "Invalid combo '$command', '$type', '$character' passed to pushCommand" if !$command || !$type || !$character;

    my $dbh = Kismet::DB->new();
    my $sth = $dbh->prepare('insert into system.command_queue (command, type, character) values (?,?,?)');
    $sth->execute( $command, $type, $character );
    $sth->finish;
}

sub popAllImmediateCommands {
    # Get the immediate commands from each player
    my $dbh = Kismet::DB->new();
    my $sth = $dbh->prepare("select queue_id, command, type, character from system.command_queue
                             where type in ($CMD_TYPE_SERVER, $CMD_TYPE_IMMEDIATE)");
    $sth->execute();
    my @commands;
    while( my $href = $sth->fetchrow_hashref() ) {
        push @commands, $href;
    }
    $sth->finish;

    return wantarray ? @commands : \@commands;
}

sub popAllMovementCommands {
    # Get the oldest command from each player
    my $dbh = Kismet::DB->new();
    my $sth = $dbh->prepare("select queue_id, command, type, character from system.command_queue
                             where type = $CMD_TYPE_MOVEMENT
                             order by queue_id");
    $sth->execute();
    # Hash the commands to remove duplicates since I'm lazy TODO - do this in query
    my %commands;
    while( my $href = $sth->fetchrow_hashref() ) {
        $commands{$href->{CHARACTER}} = $href if !defined($commands{$href->{CHARACTER}}); 
    }
    $sth->finish;

    my @commands = shuffle values %commands; # Shuffle them in random order to reduce any advantage to faster connections
    return wantarray ? @commands : \@commands;
}

sub popAllCombatCommands {
    # Get the oldest command from each player
    my $dbh = Kismet::DB->new();
    my $sth = $dbh->prepare("select queue_id, command, type, character from system.command_queue
                             where type = $CMD_TYPE_COMBAT 
                             order by queue_id");
    $sth->execute();
    # Hash the commands to remove duplicates since I'm lazy TODO - do this in query
    my %commands;
    while( my $href = $sth->fetchrow_hashref() ) {
        $commands{$href->{CHARACTER}} = $href if !defined($commands{$href->{CHARACTER}}); 
    }
    $sth->finish;

    my @commands = shuffle values %commands; # Shuffle them in random order to reduce any advantage to faster connections
    return wantarray ? @commands : \@commands;
}

1;
