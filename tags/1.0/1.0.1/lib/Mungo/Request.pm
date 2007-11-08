package Mungo::Request;

# Copyright (c) 2007 OmniTI Computer Consulting, Inc. All rights reserved.
# For information on licensing see:
#   https://labs.omniti.com/zetaback/trunk/LICENSE

use strict;
use Mungo::Cookie;
use Mungo::MultipartFormData;
eval "use APR::Table;";
our $AUTOLOAD;

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
    elsif($ct eq 'application/x-www-form-urlencoded') {
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

sub Cookies {
  my $self = shift;
  my $ccls = 'Mungo::Cookie';
  my $cookie = $self->{$ccls} ||= $ccls->new($self->{'Apache::Request'});
  return $cookie->__get(@_);
}
sub QueryString {
  my $self = shift;
  my (@params) = $self->{'Mungo'}->{'Apache::Request'}->args;
  my %qs;
  if(@params == 1) {
    # in mod_perl2 ->args is just a string
    %qs = (map { (split /=/, $_, 2) } (split /&/, $params[0]));
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

sub ServerVariables {
  my $self = shift;
  my $var = shift;
  if($var eq 'DOCUMENT_ROOT') {
    return $self->{'Mungo'}->{'Apache::Request'}->document_root;
  }
  elsif($var eq 'HTTP_HOST') {
    return $self->{'Mungo'}->{'Apache::Request'}->hostname;
  }
  return undef;
}

sub AUTOLOAD {
  my $self = shift;
  die unless(ref $self);
  my $name = $AUTOLOAD;
  $name =~ s/.*://;   # strip fully-qualified portion
  die __PACKAGE__." does not implement $name";
}

1;
