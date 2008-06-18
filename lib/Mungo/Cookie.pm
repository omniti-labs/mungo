package Mungo::Cookie;

# Copyright (c) 2007 OmniTI Computer Consulting, Inc. All rights reserved.
# For information on licensing see:
#   https://labs.omniti.com/zetaback/trunk/LICENSE

=head1 NAME

Mungo::Cookie - Cookie support class

=head1 SYNOPSIS

  # Use via Mungo::Request->Cookies
  my $value = $Request->cookies($cookie_name, $key_name);

=head1 DESCRIPTION

Represents one or more 

=cut

use strict;
use Mungo::Utils;
eval "use APR::Table;";

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

# Private constructor.
# $cookiejar = Mungo::Cookie->new($apache_req);
# $cookiejar = Mungo::Cookie->new($raw_cookie_string);
#   Splits the incoming cookie string on ; to find sub-cookies
#  If subcookie has a single value (with no key):
#   $self->{$subcookie_name}->{Value} = $value
#  If subcookie has a key-value pairs:
#   $self->{$subcookie_name}->{Value}->{$key} = $value;
sub new {
  my $class = shift;
  my $arg = shift;
  my $cstr =  (ref $arg && UNIVERSAL::can($arg, 'headers_in')) ? # pull from
                $arg->headers_in->get('Cookie') :      # Apache2::RequestRec
                (ref $arg && UNIVERSAL::can($arg, 'header_in')) ?
                  $arg->header_in('Cookie') :          # Apache::Request
                  $arg;                                # or a passed string
  my $self = bless {}, $class;
  foreach my $cookie (split /;\s*/, $cstr) {        # ; seperated cookies
      # $cname = subcookie name
      # @lk = list of key, value pairs in subcookie
      # @kv = a key, value pair in a subcookie
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
    "->inject_header requires Apache2::RequestRec or Apache::Request or Mungo::Response"
      if(!$r || (!UNIVERSAL::can($r, 'headers_out') &&
                 !UNIVERSAL::can($r, 'header_out')));
  # $r is our Apache::Request at this point
  while(my ($cname, $info) = each %$self) {
    my $cookiestr = $self->make_cookie_string($cname, $info);
    $r->can('headers_out') ?
      $r->headers_out->add('Set-Cookie', $cookiestr) :
      $r->header_out('Set-Cookie', $cookiestr);
  }
  return;
}

# Sigh.  "friend" method.

# Why???
# $cookie_object = $cookie_object->__get();

# If $cookie_name is single-valued....
#  $value = $cookie_object->__get($cookie_name);

# If $cookie_name is multi-valued....
#  $hashref = $cookie_object->__get($cookie_name);

# If $cookie_name is multi-valued....
#  $value = $cookie_object->__get($cookie_name, $key);

sub __get {
  my $self = shift;
  # Short circuit if no args were given
  return $self unless(@_);

  my $cookie_name = shift;
  if(@_) {
    my $key = shift;
    return (exists $self->{$cookie_name} && ref $self->{$cookie_name}->{Value} eq 'HASH' &&
            exists $self->{$cookie_name}->{Value}->{$key}) ?
             $self->{$cookie_name}->{Value}->{$key} :
             undef;
  }
  return (exists $self->{$cookie_name}->{Value}) ? $self->{$cookie_name}->{Value} : undef;
}


# $cookie->__set($cookie_name, $value);
# $cookie->__set($cookie_name, $key, $value);
# $cookie->__set($cookie_name, 'Expires', $value);
# $cookie->__set($cookie_name, 'Path', $value);
# $cookie->__set($cookie_name, 'Domain', $value);
# $cookie->__set($cookie_name, 'Secure', $value);

sub __set {
  my $self = shift;
  my $cname = shift;
  my $value = shift;
  my $key = undef;
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
