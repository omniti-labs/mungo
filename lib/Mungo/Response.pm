package Mungo::Response;

# Copyright (c) 2007 OmniTI Computer Consulting, Inc. All rights reserved.
# For information on licensing see:
#   https://labs.omniti.com/zetaback/trunk/LICENSE

=head1 NAME

Mungo::Response - Represent response side of HTTP request cycle

=head1 SYNOPSIS

  <!-- You get a Response object for free when you use Mungo -->
  <% if ($Response) { ... } %>

  <!-- Read and Mungo-process other files -->
  <%
     # Prints to browser
     $Response->Include('/some/file.html', $arg1);

     # Caputured
     my $output = $Response->TrapInclude('/some/file.html');

     # Can also print to browser via Response
     print $Response "Hello world!";
  %>

  <!-- May also set headers -->
  <%
     $Response->AddHeader('header_name' => $value);
  %>

  <!-- Halt processing and jump out of the handler -->
  <%
     # With a 302
     $Response->Redirect('/new/url/');

     # Just end
     $Response->End();
  %>

  <!-- Cookie facility -->
  <%
     # Single valued cookies
     $Response->Cookies($cookie_name, $cookie_value);

     # Multivalued cookies
     $Response->Cookies($cookie_name, $key, $value);

     # Cookie options
     $Response->Cookies($cookie_name, 'Domain', $value);
     $Response->Cookies($cookie_name, 'Expires', $value);
     $Response->Cookies($cookie_name, 'Path', $value);
     $Response->Cookies($cookie_name, 'Secure', $value);
  %>

=head1 DESCRIPTION

Represents the response side of the Mungo request cycle.

=cut


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
  my $_r = tied %$self;
  if(ref $_r->{data}->{'IO_stack'} eq 'ARRAY') {
    while (@{$_r->{data}->{'IO_stack'}}) {
      my $fh = pop @{$_r->{data}->{'IO_stack'}};
      close(select($fh));
    }
  }
  delete $_r->{data}->{$_} for keys %$self;
  untie %$self if tied %$self;
}

sub send_http_header {
  my $self = shift;
  my $_r = tied %$self;
  my $r = $_r->{data}->{'Apache::Request'};
  return if($_r->{data}->{'__HEADERS_SENT__'});
  $_r->{data}->{'__HEADERS_SENT__'} = 1;
  if($_r->{data}->{CacheControl} eq 'no-cache') {
    $r->no_cache(1);
  }
  else {
    if($r->can('headers_out')) {
      $r->headers_out->set('Cache-Control' => $_r->{data}->{CacheControl});
    }
    else {
      $r->header_out('Cache-Control' => $_r->{data}->{CacheControl});
    }
  }
  # Must use Internal as the tiehash is magic for cookies
  $_r->{'__Internal__'}->{Cookies}->inject_headers($r);
  $r->status($_r->{data}->{Status});
  $r->can('send_http_header') ?
    $r->send_http_header($_r->{data}->{ContentType}) :
    $r->content_type($_r->{data}->{ContentType});;
}

sub start {
  my $self = shift;
  my $_r = tied %$self;
  return if(exists $_r->{data}->{'IO_stack'} &&
            scalar(@{$_r->{data}->{'IO_stack'}}) > 0);
  $_r->{data}->{'IO_stack'} = [];
  tie *DIRECT, ref $self, $self;
  push @{$_r->{data}->{'IO_stack'}}, select(DIRECT);
}

sub finish {
  my $self = shift;
  my $_r = tied %$self;
  # Unbuffer outselves, this will actually induce a flush (must go through tiehash)
  $_r->{'__Internal__'}->{Buffer} = 0;
  untie *DIRECT if tied *DIRECT;
  return unless(exists $_r->{data}->{'IO_stack'});
  my $fh = $_r->{data}->{'IO_stack'}->[0];
  die __PACKAGE__." IO stack of wrong depth" if(scalar(@{$_r->{data}->{'IO_stack'}}) != 1);
}

=head2 $Response->AddHeader('header_name' => 'header_value');

Adds an HTTP header to the response.

Dies if headers (or any other output) has already been sent.

=cut

sub AddHeader {
  my $self = shift;
  my $_r = tied %$self;
  my $r = $_r->{data}->{'Apache::Request'};
  die "Headers already sent." if($_r->{data}->{'__HEADERS_SENT__'});
  $r->can('headers_out') ? $r->headers_out->set(@_) : $r->header_out(@_);
}
sub Cookies {
  my $self = shift;
  my $_r = tied %$self;
  die "Headers already sent." if($_r->{data}->{'__HEADERS_SENT__'});
  # Must use Internal as the tiehash is magic for cookies
  my $cookie = $_r->{'__Internal__'}->{'Cookies'};
  $cookie->__set(@_);
}

=head2 $Response->Redirect($url);

Issues a 302 redirect with the new location as $url.

Dies if headers (or any other output) has already been sent.

=cut

sub Redirect {
  my $self = shift;
  my $url = shift;
  my $_r = tied %$self;
  die "Cannot redirect, headers already sent\n" if($_r->{data}->{'__HEADERS_SENT__'});
  $_r->{data}->{Status} = shift || 302;
  my $r = $_r->{data}->{'Apache::Request'};
  $r->can('headers_out') ? $r->headers_out->set('Location', $url) :
                           $r->header_out('Location', $url);
  $self->send_http_header();
  $self->End();
}


=head2 $res->Include($filename, $arg1, $arg2, ...);

=head2 $res->Include(\$string, $arg1, $arg2, ...);

Reads the given filename or string and interprets it as Mungo ASP code.

Any passed arguments are available in the @_ array within the ASP code.

The results of evaluating the code is printed to STDOUT.

=cut

sub Include {
  my $self = shift;
  my $subject = shift;
  my $_r = tied %$self;
  my $rv;
  eval {
    local $SIG{__DIE__} = \&Mungo::MungoDie;
    if(ref $subject) {
      $rv = $_r->{data}->{Mungo}->include_mem($subject, @_);
    }
    else {
      $rv = $_r->{data}->{Mungo}->include_file($subject, @_);
    }
  };
  if($@) {
    # If we have more than 1 item in the IO stack, we should just re-raise.
    if (scalar(@{$_r->{data}->{'IO_stack'} || []}) > 1) {
      local $SIG{__DIE__} = undef;
      die $@;
    }
    my $hashref = $@;
    eval {
      if($_r->{data}->{OnError}) {
        $_r->{data}->{OnError}->($self, $hashref, $subject);
      }
      else {
        $self->defaultErrorHandler($hashref, $subject);
      }
    };
    if($@) {
      # Oh, dear lord this is bad.  We'd died trying to print out death.
      print STDERR "Mungo::Response -> die in error renderer\n";
      print STDERR $hashref;
      print STDERR $@;
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
  my $_r = tied %$self;
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
    if($_r->{data}->{'Apache::Request'}->dir_config('Debug')) {
      print Mungo::Utils::pretty_print_code($preamble, $contents, $postamble, $href->{callstack}->[0]->[2]);
    }
  } else {
    print '<pre>'.Dumper($@).'</pre>';
  }
}

=head2 $output = $Response->TrapInclude($filename, @args);

Like Include(), but results are returned as a string, instead of being printed.

=cut

sub TrapInclude {
  my $self = shift;
  my $_r = tied %$self;
  my $output;
  my $handle = \do { local *HANDLE };
  tie *{$handle}, 'Mungo::Response::Trap', \$output;
  push @{$_r->{data}->{'IO_stack'}}, select(*{$handle});
  eval {
    $self->Include(@_);
  };
  untie *{$handle} if tied *{$handle};
  select(pop @{$_r->{data}->{'IO_stack'}});
  if($@) {
    local $SIG{__DIE__} = undef;
    die $@;
  }
  return $output;
}

=head2 $Response->End()

Stops processing the current response, shuts down the 
output handle, and jumps out of the response handler.  
No further processing will occur.

=cut

sub End {
  my $self = shift;
  my $_r = tied %$self;
  while(scalar(@{$_r->{data}->{'IO_stack'} || []}) > 1) {
    my $oldfh = select(pop @{$_r->{data}->{'IO_stack'}});
    if(my $obj = tied *{$oldfh}) {
      untie *{$oldfh};
      print $$obj;
    }
  }
  $self->Flush();
  eval { goto  MUNGO_HANDLER_FINISH; }; # Jump back to Mungo::handler()
}

sub Flush {
  my $self = shift;
  my $_r = tied %$self;
  # Flush doesn't apply unless we're immediately above STDOUT
  return if(scalar(@{$_r->{data}->{'IO_stack'} || []}) > 1);
  unless($_r->{data}->{'__OUTPUT_STARTED__'}) {
    $self->send_http_header;
    $_r->{data}->{'__OUTPUT_STARTED__'} = 1;
  }
  if (@{$_r->{data}->{'IO_stack'} || []}) {
      $_r->{data}->{'IO_stack'}->[-1]->print($one_true_buffer);
  } else {
      print $one_true_buffer;
  }

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
  my $_r = tied %$self;
  if(scalar(@{$_r->{data}->{'IO_stack'} || []}) == 1) {
    # Buffering a just-in-time headers only applies if we
    # immediately above STDOUT
    if($_r->{data}->{Buffer}) {
      $one_true_buffer .= $output;
      return;
    }
    unless($_r->{data}->{'__OUTPUT_STARTED__'}) {
      $_r->{data}->{'__OUTPUT_STARTED__'} = 1;
      $self->send_http_header;
    }
  }
  if (@{$_r->{data}->{'IO_stack'} || []}) {
      $_r->{data}->{'IO_stack'}->[-1]->print($output);
  } else {
      print $output;
  }
}
sub PRINTF {
  my $self = shift;
  my $_r = tied %$self;
  if(scalar(@{$_r->{data}->{'IO_stack'} || []}) == 1) {
    # Buffering a just-in-time headers only applies if we
    # immediately above STDOUT
    if($_r->{data}->{Buffer}) {
      $one_true_buffer .= sprintf(@_);
      return;
    }
    unless($_r->{data}->{'__OUTPUT_STARTED__'}) {
      $_r->{data}->{'__OUTPUT_STARTED__'} = 1;
      $self->send_http_header;
    }
  }
  if (@{$_r->{data}->{'IO_stack'} || []}) {
      $_r->{data}->{'IO_stack'}->[-1]->printf(@_);
  } else {
      printf(@_);
  }
}
sub CLOSE {
  my $self = shift;
  my $_r = tied %$self;
  # Unbuffer outselves, this will actually induce a flush (must go through tiehash)
  $_r->{data}->{Buffer} = 0;
}
sub UNTIE { }

=head1 AUTHOR

Theo Schlossnagle

Clinton Wolfe (docs)

=cut

1;
