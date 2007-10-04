package Mungo::Response;

# Copyright (c) 2007 OmniTI Computer Consulting, Inc. All rights reserved.
# For information on licensing see:
#   https://labs.omniti.com/zetaback/trunk/LICENSE

use strict;
use IO::Handle;
use Mungo::Arbiter::Response;
use Mungo::Response::Trap;
use Mungo::Cookie;
use Mungo::Utils;
use HTML::Entities;
our $AUTOLOAD;

my $one_true_buffer = '';

sub new {
  my $class = shift;
  my $parent = shift;
  my $r = $parent->{'Apache::Request'};
  my $singleton = $r->pnotes(__PACKAGE__);
  return $singleton if ($singleton);
  my %core_data = (
    'Apache::Request' => $r,
    'ContentType' => $r->dir_config('MungoContentType') || $r->content_type || 'text/html',
    # We don't set buffer here, we set it after it has been tied.
    # 'Buffer' => $r->dir_config('MungoBuffer') || 0,
    'Buffer' => 0,
    'CacheControl' => $r->dir_config('MungoCacheControl') || 'private',
    'Charset' => $r->dir_config('MungoCharset') || undef,
    'Status' => 200,
    'Mungo' => $parent,
    'CookieClass' => $r->dir_config('MungoCookieClass') || 'Mungo::Cookie',
    'Cookies' => undef, # placeholder for visibility
  );
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
  if(ref $self->{'IO_stack'} eq 'ARRAY') {
    while (@{$self->{'IO_stack'}}) {
      my $fh = pop @{$self->{'IO_stack'}};
      close(select($fh));
    }
  }
  delete $self->{$_} for keys %$self;
  untie %$self if tied %$self;
}

sub send_http_header {
  my $self = shift;
  my $r = $self->{'Apache::Request'};
  return if($self->{'__HEADERS_SENT__'});
  $self->{'__HEADERS_SENT__'} = 1;
  if($self->{CacheControl} eq 'no-cache') {
    $r->no_cache(1);
  }
  else {
    $r->header_out('Cache-Control', $self->{CacheControl});
  }
  $self->{Cookies}->inject_headers($r);
  $r->status($self->{Status});
  $r->send_http_header($self->{ContentType});
}

sub start {
  my $self = shift;
  return if(exists $self->{'IO_stack'} &&
            scalar(@{$self->{'IO_stack'}}) > 0);
  $self->{'IO_stack'} = [];
  tie *DIRECT, ref $self, $self;
  push @{$self->{'IO_stack'}}, select(DIRECT);
}

sub finish {
  my $self = shift;
  # Unbuffer outselves, this will actually induce a flush
  $self->{Buffer} = 0;
  untie *DIRECT if tied *DIRECT;
  return unless(exists $self->{'IO_stack'});
  my $fh = $self->{'IO_stack'}->[0];
  delete $self->{'IO_stack'};
  die __PACKAGE__." IO stack of wrong depth" if(scalar(@{$self->{'IO_stack'}}) != 1);
}

sub AddHeader {
  my $self = shift;
  my $r = $self->{'Apache::Request'};
  die "Headers already sent." if($self->{'__HEADERS_SENT__'});
  $r->header_out(@_);
}
sub Cookies {
  my $self = shift;
  die "Headers already sent." if($self->{'__HEADERS_SENT__'});
  my $cookie = $self->{'Cookies'};
  $cookie->__set(@_);
}
sub Redirect {
  my $self = shift;
  my $url = shift;
  die "Cannot redirect, headers already sent\n" if($self->{'__HEADERS_SENT__'});
  $self->{Status} = shift || 302;
  $self->{'Apache::Request'}->header_out('Location', $url);
  $self->send_http_header();
  $self->End();
}
sub Include {
  my $self = shift;
  my $subject = shift;
  my $rv;
  eval {
    if(ref $subject) {
      $rv = $self->{'Mungo'}->include_mem($subject, @_);
    }
    else {
      $rv = $self->{'Mungo'}->include_file($subject, @_);
    }
  };
  if($@) {
    my $href = $@;
    eval {
      if($self->{OnError}) {
        $self->{OnError}->($self, $href, $subject);
      }
      else {
        $self->defaultErrorHandler($href, $subject);
      }
    };
    if($@) {
      # Oh, dear lord this is bad.  We'd died trying to print out death.
      print '<pre>'.Dumper($@).'</pre>';
    }
    return undef;
  }
  return $rv;
}

sub defaultErrorHandler {
  use Data::Dumper;
  my $self = shift;
  my $href = shift; # Our Error
  my $subject = shift;
  print "Error in Include($subject):<br />\n";
  my $pkg = $href->{callstack}->[0]->[0];
  my $preamble = eval "\$${pkg}::Mungo_preamble;";
  my $postamble = eval "\$${pkg}::Mungo_postamble;";
  my $contents = eval "\$${pkg}::Mungo_contents;";
  print "<pre class=\"error\">$href->{error}</pre><br />\n";

  unless($contents) {
    my $filename = $href->{callstack}->[0]->[1];
    if(open(FILE, "<$filename")) {
      local $/ = undef;
      $$contents = <FILE>;
      close(FILE);
    }
  }

  if($contents) {
    if($self->{'Apache::Request'}->dir_config('Debug')) {
      print Mungo::Utils::pretty_print_code($preamble, $contents, $postamble, $href->{callstack}->[0]->[2]);
    }
  } else {
    print '<pre>'.Dumper($@).'</pre>';
  }
}

sub TrapInclude {
  my $self = shift;
  my $output;
  my $handle = \do { local *HANDLE };
  tie *{$handle}, 'Mungo::Response::Trap', \$output;
  push @{$self->{'IO_stack'}}, select(*{$handle});
  eval {
    $self->Include(@_);
  };
  untie *{$handle} if tied *{$handle};
  select(pop @{$self->{'IO_stack'}});
  die $@ if $@;
  return $output;
}
sub End {
  shift->Flush();
  eval { goto MUNGO_HANDLER_FINISH; };
}
sub Flush {
  my $self = shift;
  # Flush doesn't apply unless we're immediately above STDOUT
  return if(scalar(@{$self->{'IO_stack'}}) > 1);
  unless($self->{'__OUTPUT_STARTED__'}) {
    $self->send_http_header;
    $self->{'__OUTPUT_STARTED__'} = 1;
  }
  $self->{'IO_stack'}->[-1]->print($one_true_buffer);
  $one_true_buffer = '';
}

sub AUTOLOAD {
  my $self = shift;
  my $name = $AUTOLOAD;
  $name =~ s/.*://;   # strip fully-qualified portion
  die __PACKAGE__." does not implement $name";
}

sub TIEHANDLE {
  my $class = shift;
  my $self = shift;
  return $self;
}
sub PRINT {
  my $self = shift;
  my $output = shift;
  if(scalar(@{$self->{'IO_stack'}}) == 1) {
    # Buffering a just-in-time headers only applies if we
    # immediately above STDOUT
    if($self->{Buffer}) {
      $one_true_buffer .= $output;
      return;
    }
    unless($self->{'__OUTPUT_STARTED__'}) {
      $self->{'__OUTPUT_STARTED__'} = 1;
      $self->send_http_header;
    }
  }
  $self->{'IO_stack'}->[-1]->print($output);
}
sub PRINTF {
  my $self = shift;
  if(scalar(@{$self->{'IO_stack'}}) == 1) {
    # Buffering a just-in-time headers only applies if we
    # immediately above STDOUT
    if($self->{Buffer}) {
      $one_true_buffer .= sprintf(@_);
      return;
    }
    unless($self->{'__OUTPUT_STARTED__'}) {
      $self->{'__OUTPUT_STARTED__'} = 1;
      $self->send_http_header;
    }
  }
  $self->{'IO_stack'}->[-1]->printf(@_);
}
sub CLOSE {
  my $self = shift;
  $self->{Buffer} = 0;
}
sub UNTIE { }

1;
