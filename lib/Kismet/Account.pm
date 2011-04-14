package Kismet::Account;

use Kismet::Object;
use Kismet::DB;

my @ISA = qw/Kismet::Object/;

sub new {
    my $self = shift;
    my $class = ref($self) || $self;
    my $arg = shift;
    if( $arg ) {
        return Kismet::Account::loadFromId( $arg );
    }
    $self = bless {}, $class;
    return $self;
}

sub loadFromId {
    my $id = shift;

    my $dbh = Kismet::DB->new();
    my $sth = $dbh->prepare('select * from system.accounts where accountid = ?');
    $sth->execute( $id );
    my $href = $sth->fetchrow_hashref();
    $sth->finish;
    return undef if !$href;
    $self = bless $href, 'Kismet::Account';
    return $href;
}

sub loadFromCookie {
    my $self = shift;
    # TODO - this needs to get checked, and also set the loaded character name as well
    my $cookie    = $main::Request->Cookies( "session" );
    $cookie =~ /(\d+):(\d+)/;
    my ($accountid, $charid) = ($1, $2);
    my $acc = Kismet::Account::loadFromId( $accountid );
    $main::Response->Redirect('login.asp') if !$acc;
    $acc->logged_char( $charid );
    return $acc;
}

sub setLoginCookie {
    my $self = shift;
    # TODO - put a real checkable cookie, and include an optional loaded character name + arbitrary stuff
    $main::Response->Cookies( "session", $self->accountid . ":" . $self->logged_char );
}

sub clearLoginCookie {
    my $self = shift;
    $main::Response->Cookies( "session", 'Expires', '-24h' );
}

sub getAllAccounts {
    my $self = shift;

    my $dbh = Kismet::DB->new();
    my $sth = $dbh->prepare('select * from system.accounts');
    $sth->execute();
    my @accounts;
    while( my $href = $sth->fetchrow_hashref() ) {
        push @accounts, bless $href, 'Kismet::Account';
    }
    $sth->finish;
    return wantarray ? @accounts : \@accounts;
}

sub characters {
    my $self = shift;

    return ( wantarray ? @{$self->{characters}} : $self->{characters} ) if $self->{characters};

    my $dbh = Kismet::DB->new();
    my $sth = $dbh->prepare('select * from system.characters where accountid = ?');
    $sth->execute( $self->accountid );
    my @chars;
    while( my $href = $sth->fetchrow_hashref() ) {
        push @chars, $href;
    }
    $sth->finish;
    $self->{characters} = \@chars;
    return wantarray ? @{$self->{characters}} : $self->{characters};
}

for (qw/accountid name password logged_char/) {
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
