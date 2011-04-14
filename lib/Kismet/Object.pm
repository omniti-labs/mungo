package Kismet::Object;

my $object_uid_sequence = 0;

sub new {
    my $self = shift;
    my $class = ref($self) || $self;
    $self = bless {}, $class;
    $self->{__uid} = ++$object_uid_sequence;
    return $self;
}

sub uid {
    my $self = shift;
    return $self->{__uid};
}

1;
