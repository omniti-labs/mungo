package Mungo::Cookie;

# Copyright (c) 2007 OmniTI Computer Consulting, Inc. All rights reserved.
# For information on licensing see:
#   https://labs.omniti.com/zetaback/trunk/LICENSE

use strict;
use Mungo::Utils;

my %reserved = (
  'Expires' => 1,
  'Domain'  => 1,
  'Path'    => 1,
  'Secure'  => 1,
);

my %time_multiplier = (
  's' => 1,
  'm' => 60,
  'h' => 3600,
  'd' => 86400,
  'w' => 604800,
  'M' => 2592000,
  'y' => 31536000
);

sub new {
  my $class = shift;
  my $arg = shift;
  my $cstr =  (ref $arg && UNIVERSAL::can($arg, 'header_in')) ? # pull from
                $arg->header_in('Cookie') :         # Apache::Request
                $arg;                               # or a passed string
  my $self = bless {}, $class;
  foreach my $cookie (split /;\s*/, $cstr) {        # ; seperated cookies
    my ($cname, $rest) = split /=/, $cookie, 2;     # cookie=OPAQUE_STRING
    my @lk = ($rest !~ /[=&]/) ?                    # single value ?
               ($rest) :                            # then use that
               map {
                 my @kv = split /=/, $_, 2;         # split k(=v)?
                 (@kv == 1) ? ($kv[0], 1) : @kv;    # return (k,v||1)
               } split /&/, $rest;                  # from & delimited bits

    ($cname, @lk) = map {                           # decode all the tokens
                      s/\+/ /g;
                      s/%([0-9a-f]{2})/chr(hex($1))/ieg;
                      $_;
                    } ($cname, @lk);

    next if(exists $self->{$cname}->{Value});       # first one wins

    $self->{$cname}->{Value} = (scalar(@lk) <= 1) ?
                        $lk[0] :                    # single value
                        {my %tmp = @lk};            # value set
  }
  return $self;
}

sub make_cookie_string {
  my ($self, $cname, $info) = @_;
  my $cstring;
  if(ref $info->{Value}) {
    my ($ecname, %lk) = map { 
      s/([^a-zA-Z0-9])/sprintf("%%%02x", ord($1))/eg;
      $_;
    } ($cname, %{$info->{Value}});
    $cstring = "$ecname=";
    my @parts;
    while(my($k,$v) = each %lk) { push @parts, "$k=$v"; }
    $cstring .= join('&', @parts);
  }
  else {
    $cstring = join('=', map { 
      s/([^a-zA-Z0-9])/sprintf("%%%02x", ord($1))/eg;
      $_;
    } ($cname, $info->{Value}));
  }
  if(exists $info->{Expires}) {
    if($info->{Expires} =~ /^\d+([smhdwMy])?$/) {
      my $s = $info->{Expires} * $time_multiplier{$1 || 's'};
      $info->{Expires} = Mungo::Utils::time2str(time + $s);
    }
  }
  foreach my $attr (grep { $_ ne 'Secure' } keys %reserved) {
    if(exists $info->{$attr}) {
      $cstring .= "; ".lc($attr)."=".$info->{$attr};
    }
  }
  if(exists $info->{Secure} && $info->{Secure}) {
    $cstring .= "; secure";
  }
  return $cstring;
}
sub inject_headers {
  my $self = shift;
  my $Response = shift;
  my $r = $Response;
  if(UNIVERSAL::isa($Response,'Mungo::Response')) {
    $r = $Response->{'Apache::Request'};
  }
  die __PACKAGE__ .
    "->inject_header requires Apache::Request or Mungo::Response"
      if(!$r || !UNIVERSAL::can($r, 'header_out'));
  # $r is our Apache::Request at this point
  while(my ($cname, $info) = each %$self) {
    $r->header_out('Set-Cookie', $self->make_cookie_string($cname, $info));
  }
  return;
}

sub __get {
  my $self = shift;
  # Short circuit if no args were given
  return $self unless(@_);

  my $key = shift;
  if(@_) {
    my $part = shift;
    return (exists $self->{$key} && ref $self->{$key}->{Value} eq 'HASH' &&
            exists $self->{$key}->{Value}->{$part}) ?
             $self->{$key}->{Value}->{$part} :
             undef;
  }
  return (exists $self->{$key}->{Value}) ? $self->{$key}->{Value} : undef;
}

sub __set {
  my $self = shift;
  my $cname = shift;
  my $key = undef;
  my $value = shift;
  if(@_) {
    $key = $value;
    $value = shift;
  }
  $self->{$cname} ||= {};
  if(!defined($key)) {
    $self->{$cname}->{Value} = $value;
  }
  else {
    if(exists $reserved{ucfirst(lc($key))}) {
      $self->{$cname}->{ucfirst(lc($key))} = $value;
    }
    else {
      $self->{$cname}->{Value} = {}
        unless(ref $self->{$cname}->{Value} eq 'HASH');
      $self->{$cname}->{Value}->{$key} = $value;
    }
  }
}
1;
