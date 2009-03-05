package Mungo::Request;

# Copyright (c) 2007 OmniTI Computer Consulting, Inc. All rights reserved.
# For information on licensing see:
#   https://labs.omniti.com/zetaback/trunk/LICENSE

use strict;
use Mungo::Cookie;
use Mungo::MultipartFormData;
eval "use APR::Table;";
our $AUTOLOAD;

=head1 NAME

Mungo::Request - represent an HTTP request context

=head1 SYNOPSIS

  <!-- Within your HTML, you get a Request object for free -->
  <% if (defined $Request) { ... } %>

  <!-- Get params -->
  <%
     my $value = $Request->Params('param_name');
     my %params = $Request->Params();
  %>

  <!-- Get Request Info -->
  <%
     my $refer = $Request->ServerVariables('REFERER');
     my $refer = $Request->ServerVariables('REFERRER'); # Same
     my $server_hostname = $Request->ServerVariables('HTTP_HOST');
     my $client_ip = $Request->ServerVariables('REMOTE_IP'); # If proxied, uses HTTP_X_FORWARDED_FOR.

     my $header = $Request->Header('HeaderName');

  %>

  <!-- Get cookies -->
  <%
     # for single-valued cookies
     my $value = $Request->Cookies($cookie_name);

     # for multi-valued cookies
     my $hashref = $Request->Cookies($cookie_name);

     # for multi-valued cookies
     my $value = $Request->Cookies($cookie_name, $key);

  %>

=head1 DESCRIPTION

Represents the request side of a Mungo request cycle.

See Mungo, and Mungo::Request.

=cut


sub new {
  my $class = shift;
  my $parent = shift;
  my $r = $parent->{'Apache::Request'};
  my $singleton = $r->pnotes(__PACKAGE__);
  return $singleton if ($singleton);
  my %core_data = (
    'Apache::Request' => $r,
    'Method' => $r->method,
    'Mungo' => $parent,
  );
  my $cl = $r->can('headers_in') ? $r->headers_in->get('Content-length') :
                                   $r->header_in('Content-length');
  my $ct = $r->can('headers_in') ? $r->headers_in->get('Content-Type') :
                                   $r->header_in('Content-Type');
  if($r->method eq 'POST' && $cl) {
    $core_data{TotalBytes} = $cl;
    if($ct =~ /^multipart\/form-data             # multipart form data
               \s*;\s*                           # followed by a
               boundary=\"?([^\";,]+)\"?/x) {    # boundary phrase
      my $boundary = $1;
      $core_data{multipart_form} =
        Mungo::MultipartFormData->new($r, $cl, $boundary);
    }
    elsif($ct =~ /^application\/x-www-form-urlencoded\s*(?:;.*)?/) {
      $r->read($core_data{'form_content'}, $core_data{TotalBytes});
    }
  }
  my %data;
  $singleton = bless \%data, $class;
  tie %data, 'Mungo::Arbiter::Response', $singleton, \%core_data;
  $singleton->{Buffer} = $r->dir_config('MungoBuffer') || 0;
  $r->pnotes(__PACKAGE__, $singleton);
  return $singleton;
}

sub DESTROY {
  my $self = shift;
  $self->cleanse();
}

sub cleanse {
  my $self = shift;
  delete $self->{$_} for keys %$self;
  untie %$self if tied %$self;
}

=head2 $value = $Request->Cookies($cookie_name);

=head2 $hashref = $Request->Cookies($cookie_name);

=head2 $value = $Request->Cookies($cookie_name, $key);

Reads and parses incoming cookie data.  Behavior depends on whether 
the cookie contained name-value pairs.

If not, the first form simply returns the value set in the given cookie name, or undef.

If name-value pairs are present, the second form returns a hashref of all the name-value pairs.

If name-value pairs are present, the third form returns the value for the given key.

If no such cookie with the given name exists, returns undef.

=cut

sub Cookies {
  my $self = shift;
  my $cookie_class = 'Mungo::Cookie';
  my $cookie = $self->{$cookie_class} ||= $cookie_class->new($self->{'Apache::Request'});
  return $cookie->__get(@_);
}

=head2 $value = $Request->QueryString($name);

=head2 %params = $Request->QueryString();

=head2 $params_hashref = $Request->QueryString();

Returns one value (first form) or all values (second and third forms)
from the submitted query string.

Params() is preferred.

=cut

sub QueryString {
  my $self = shift;
  my (@params) = $self->{'Mungo'}->{'Apache::Request'}->args;
  my %qs;
  if(@params == 1) {
    # in mod_perl2 ->args is just a string
    %qs = map { s/\+/ /g; s/%([0-9a-f]{2})/chr(hex($1))/ige; $_ }
              (map { (split /=/, $_, 2) } (split /&/, $params[0]));
  }
  else {
    # mod_perl1 splits it up for us
    %qs = @params;
  }
  return exists($qs{$_[0]})?$qs{$_[0]}:undef if(@_);
  return %qs if wantarray;
  return \%qs;
}

sub decode_form {
  my $class = ref $_[0] ? ref $_[0] : $_[0];
  my $form_content = $_[1];
  my $form = {};
  return $form unless($form_content);
  foreach my $kv (split /[&;]/, $form_content) {
    my($k, $v) = map { s/\+/ /g;
                       s/%([0-9a-f]{2})/chr(hex($1))/ige;
                       $_;
                     } split(/=/, $kv, 2);
    if(ref $form->{$k}) {
      push @{$form->{$k}}, $v;
    }
    else {
      $form->{$k} = exists($form->{$k}) ? [$form->{$k}, $v] : $v;
    }
  }
  return $form;
}

=head2 $value = $Request->Form($name);

=head2 %params = $Request->Form();

=head2 $params_hashref = $Request->Form();

Returns one value (first form) or all values (second and third forms)
from the submitted POST data.

Params() is preferred.

=cut

sub Form {
  my $self = shift;
  my $form;
  if(!$self->{form_content} && !$self->{multipart_form}) {
    return undef if(@_);
    return () if wantarray;
    return {};
  }
  unless(exists $self->{Form}) {
    $self->{Form} = $self->decode_form($self->{form_content})
      if($self->{form_content});
    $self->{Form} = $self->{multipart_form} if($self->{multipart_form});
  }
  $form = $self->{Form};
  return exists($form->{$_[0]})?$form->{$_[0]}:undef if(@_);
  return %$form if wantarray;
  return $form;
}

=head2 $value = $Request->Params($name);

=head2 %params = $Request->Params();

=head2 $params_hashref = $Request->Params();

Returns one value (first form) or all values (second and third forms)
from the submitted CGI parameters, whether that was via the query string or via POST data.

This method is recommended over Form and QueryString, because it is independent 
of how the data was submitted.

If both methods provide data, Form overrides QueryString.

=cut

sub Params {
  my $self = shift;
  return $self->Form($_[0]) || $self->QueryString($_[0]) if(@_);
  my %base = $self->QueryString();
  my $overlay = $self->Form();
  while(my ($k, $v) = each %$overlay) {
    $base{$k} = $v;
  }
  return %base if wantarray;
  return \%base;
}

=head2 $value = $Request->ServerVariables($variable_name);

Returns information about the request or the server.  Only certain 
variables are supported:

  REFERER, REFERRER, DOCUMENT_ROOT, HTTP_HOST

=cut

sub ServerVariables {
    my $self = shift;
    my $var = shift;
    if ($var eq 'DOCUMENT_ROOT') {
        return $self->{'Mungo'}->{'Apache::Request'}->document_root;
    }
    elsif($var eq 'HTTP_HOST') {
        return $self->{'Mungo'}->{'Apache::Request'}->hostname;
    }
    elsif( ($var eq 'REFERER') || ($var eq 'REFERRER') ) {
        my $r = $self->{'Mungo'}->{'Apache::Request'};
        return $r->can('headers_in') ? $r->headers_in->get('Referer') :
                                       $r->header_in('Referer');
    }
    elsif ($var eq 'REMOTE_IP') {
        # May be proxied, and we assume our local IP is a private IP if so.
        # So look for the first non-private IP among the possible IPs.
        my @possible_ips = @ENV{qw(HTTP_X_X_FORWARDED_FOR HTTP_X_FORWARDED_FOR REMOTE_ADDR)};

        # May be a comma-separareted list, so break down into individual IPs if so.
        my @single_ips = map { split(/,\s*/, $_) } @possible_ips;

        # Eliminate private network IPs, which we assume to be the backside of a proxy server
        my @not_private_ips = grep { $_ && $_ !~ /^127\.0\.0\.1|^192\.168\.|^10\./ } @single_ips;

        # Return the first remaining address
        return $not_private_ips[0];

    }
    return undef;
}

=head2 $value = $Request->Header('User-Agent');

Returns raw header information from the request header.

=cut

sub Header {
    my $self = shift;
    my $hname = shift;
    my $r = $self->{'Mungo'}->{'Apache::Request'};
    return $r->can('headers_in')
      ? $r->headers_in->get($hname)
        : $r->header_in($hname);
}

sub AUTOLOAD {
  my $self = shift;
  die unless(ref $self);
  my $name = $AUTOLOAD;
  $name =~ s/.*://;   # strip fully-qualified portion
  die __PACKAGE__." does not implement $name";
}

=head1 AUTHOR

Theo Schlossnagle (code)

Clinton Wolfe (docs)


=cut

1;
