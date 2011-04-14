package Kismet::Request;

use Kismet::Account;

sub new {
    my $self = shift;
    my $class = ref($self) || $self;
    my $self = {@_};
    $self = bless $self, $class;

    if( not $self->{nologin_required} ) {
        my $acc = Kismet::Account->loadFromCookie();
        $Response->Redirect("login.asp") if !$acc;
        $self->{logged_account} = $acc;
    }

    return $self;
}

1;
