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
    if($r->can('headers_out')) {
      $r->headers_out->set('Cache-Control' => $self->{CacheControl});
    }
    else {
      $r->header_out('Cache-Control' => $self->{CacheControl});
    }
  }
  $self->{Cookies}->inject_headers($r);
  $r->status($self->{Status});
  $r->can('send_http_header') ?
    $r->send_http_header($self->{ContentType}) :
    $r->content_type($self->{ContentType});;
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

=head2 $Response->AddHeader('header_name' => 'header_value');

Adds an HTTP header to the response.

Dies if headers (or any other output) has already been sent.

=cut

sub AddHeader {
  my $self = shift;
  my $r = $self->{'Apache::Request'};
  die "Headers already sent." if($self->{'__HEADERS_SENT__'});
  $r->can('headers_out') ? $r->headers_out->set(@_) : $r->header_out(@_);
}
sub Cookies {
  my $self = shift;
  die "Headers already sent." if($self->{'__HEADERS_SENT__'});
  my $cookie = $self->{'Cookies'};
  $cookie->__set(@_);
}

=head2 $Response->Redirect($url);

Issues a 302 redirect with the new location as $url.

Dies if headers (or any other output) has already been sent.

=cut

sub Redirect {
  my $self = shift;
  my $url = shift;
  die "Cannot redirect, headers already sent\n" if($self->{'__HEADERS_SENT__'});
  $self->{Status} = shift || 302;
  my $r = $self->{'Apache::Request'};
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
  my $rv;
  eval {
    local $SIG{__DIE__} = \&Mungo::MungoDie;
    if(ref $subject) {
      $rv = $self->{'Mungo'}->include_mem($subject, @_);
    }
    else {
      $rv = $self->{'Mungo'}->include_file($subject, @_);
    }
  };
  if($@) {
    # If we have more than 1 item in the IO stack, we should just re-raise.
    if (scalar(@{$self->{'IO_stack'} || []}) > 1) {
      local $SIG{__DIE__} = undef;
      die $@;
    }
    my $hashref = $@;
    eval {
      if($self->{OnError}) {
        $self->{OnError}->($self, $hashref, $subject);
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

=head2 $output = $Response->TrapInclude($filename, @args);

Like Include(), but results are returned as a string, instead of being printed.

=cut

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
  while(scalar(@{$self->{'IO_stack'} || []}) > 1) {
    my $oldfh = select(pop @{$self->{'IO_stack'}});
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
  # Flush doesn't apply unless we're immediately above STDOUT
  return if(scalar(@{$self->{'IO_stack'} || []}) > 1);
  unless($self->{'__OUTPUT_STARTED__'}) {
    $self->send_http_header;
    $self->{'__OUTPUT_STARTED__'} = 1;
  }
  if (@{$self->{'IO_stack'} || []}) {
      $self->{'IO_stack'}->[-1]->print($one_true_buffer);
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
  if(scalar(@{$self->{'IO_stack'} || []}) == 1) {
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
  if (@{$self->{'IO_stack'} || []}) {
      $self->{'IO_stack'}->[-1]->print($output);
  } else {
      print $output;
  }
}
sub PRINTF {
  my $self = shift;
  if(scalar(@{$self->{'IO_stack'} || []}) == 1) {
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
  if (@{$self->{'IO_stack'} || []}) {
      $self->{'IO_stack'}->[-1]->printf(@_);
  } else {
      printf(@_);
  }
}
sub CLOSE {
  my $self = shift;
  $self->{Buffer} = 0;
}
sub UNTIE { }

=head1 AUTHOR

Theo Schlossnagle

Clinton Wolfe (docs)

=cut

1;
