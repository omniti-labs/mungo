package Mungo::Arbiter::Response;

# Copyright (c) 2007 OmniTI Computer Consulting, Inc. All rights reserved.
# For information on licensing see:
#   https://labs.omniti.com/zetaback/trunk/LICENSE

use strict;
use Mungo::Arbiter;

use vars qw/@ISA/;
@ISA = qw/Mungo::Arbiter/;

sub FETCH {
  my $self = shift;
  my $key = shift;
  if($key eq 'Cookies') {
    my $class = $self->{data}->{'CookieClass'};
    return $self->{data}->{$class} if(exists $self->{data}->{$class});
    unless(UNIVERSAL::can($class, 'new')) {
      eval "use $class;";
      die $@ if $@;
    }
    return $self->{data}->{$class} = $class->new();
  }
  return $self->SUPER::FETCH($key);
}

sub __pre_headers {
  my $self = shift;
  my $key = shift;
  my $value = shift;
  return 0 if($self->{data}->{'__HEADERS_SENT__'});
  return 1;
}

sub __autoflush {
  my $self = shift;
  my $key = shift;
  my $value = shift;
  # If we have stacked IO handlers, buffering becomes immutable
  return 0
    if($key eq 'Buffer' &&
       ref $self->{'IO_stack'} eq 'ARRAY' &&
       scalar(@{$self->{'IO_stack'}}) > 1);

  if($key eq 'Buffer' && $value == 0 &&
     $self->{data}->{$key} != 0) {
    $self->{'Mungo'}->Flush();
    return 1;
  }
  elsif($key eq 'Buffer' && $value != 0 &&
        $self->{data}->{$key} == 0) {
    return 1;
  }
  return 0;
}

sub __no_back_to_zero {
  my $self = shift;
  my $key = shift;
  my $value = shift;
  return 0 if($value == 0 && $self->{data}->{$key} != 0);
  return 1;
}

my %__check_map = (
  'Cookie' => \&Mungo::Arbiter::__immutable,
  'Status' => \&__pre_headers,
  'ContentType' => \&__pre_headers,
  'Charset' => \&__pre_headers,
  'CacheControl' => \&__pre_headers,
  'Buffer' => \&__autoflush,
  '__OUTPUT_STARTED__' => \&__no_back_to_zero,
  '__HEADERS_SENT__' => \&__no_back_to_zero,

  'Method' => \&Mungo::Arbiter::__immutable,
  'TotalBytes' => \&__immutable,
);

sub check_map {
  my $self = shift;
  my $key = shift;
  return $__check_map{$key};
}

1;
