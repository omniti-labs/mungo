package Mungo::Arbiter;

# Copyright (c) 2007 OmniTI Computer Consulting, Inc. All rights reserved.
# For information on licensing see:
#   https://labs.omniti.com/zetaback/trunk/LICENSE

sub __immutable {
  my ($self, $key) = @_;
  die "Mungo '$key' is immutable!\n";
  return 0;
}
sub __boolean {
  my ($self, $key, $value) = @_;
  return 1 if ($value =~ /^(?:0|1)$/);
  return 0;
}
sub __coderef {
  my ($self, $key, $value) = @_;
  return (ref $value eq 'CODE') ? 1 : 0;
}
sub TIEHASH {
  my $class = shift;
  my $parent = shift;
  my $data = shift;
  return bless { 'Mungo' => $parent, data => $data }, $class;
}
sub UNTIE {
  my $self = shift;
  delete $self->{'Mungo'};
}
sub FIRSTKEY {
  my $self = shift;
  my $a = keys %{$self->{data}};
  return each %{$self->{data}};
}
sub NEXTKEY {
  my $self = shift;
  return each %{$self->{data}};
}
sub FETCH {
  my $self = shift;
  my $key = shift;
  return $self->{data}->{$key};
}
sub EXISTS {
  my $self = shift;
  my $key = shift;
  return exists $self->{data}->{$key};
}
sub DELETE {
  my $self = shift;
  my @details = caller(1);
  my $key = shift;
  if($details[3] =~ /::cleanse$/) {
    delete $self->{data}->{$key};
  }
}
sub STORE {
  my ($self, $key, $value) = @_;
  my $cv = $self->check_map($key);
  if(!$cv || $cv->($self,$key,$value)) {
    $self->{data}->{$key} = $value;
  }
}

1;
