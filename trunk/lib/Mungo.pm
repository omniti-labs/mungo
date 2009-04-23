package Mungo;

=head1 NAME

Mungo - An Apache::ASP inspired lightweight ASP framework

=head1 SYNOPSIS

 # In your httpd.conf:
 <FilesMatch "\.asp$">
   SetHandler perl-script
   PerlHandler Mungo
 </FilesMatch>

 # In asp pages:
 <html>
   <%= 1 + 1; %><!-- Output: 2 -->
   <% 1 + 1; %><!-- No Output  -->

   <!-- Variable scope extends across tags -->
   <% my $pet = 'pony'; %>
   <%= $pet %><!-- you get a pony! -->

   <!-- Can embed control structures into pages -->
   <% if ($prefer_daisies) { %>
     <h2>Here are your daisies!</h2>
   <% } else { %>
     <h2>Brown-Eyed Susans, Just For You!</h2>
   <% } %>

   <!-- For, foreach, while loops, too -->
   <% foreach my $beer_num (0..99) { %>
     <p><%= 99 - $beer_num %> bottles of beer on the wall</p>
   <% } %>

   <%
      # Write arbitrary amounts of Perl here

      # you can use modules
      # (just don't define subroutines or change packages)
      use Some::Module;

      # Access info about the request
      # TODO - DOCS
      # $Request->

      # Access info about the server
      # TODO - DOCS
      # $Server->


      # Redirect to somewhere else...
      if ($want_to_redirect) {
         $Response->Redirect($url);
         # Never reach here
      }

      # Abort further processing and close outout stream
      if ($want_to_end) {
         $Response->End;
         # Never reach here
      }
   %>

   <!-- Can also include other pages or fragments -->
   <% $Response->Include($filesystem_path); %>

   <!-- may also include args -->
   <% $Response->Include($filesystem_path, @args); %>

   <!-- If args are passed to an ASP page (or page fragment) access them via @_ -->
   <%
     # In included file
     my $arg1 = shift;
   %>

   <!-- What if you want to grab that output instead of sending to the browser? -->
   <% my $output = $Response->TrapInclude($filesystem_path, @args); %>

   <!-- You can also send a string of ASP code instead of using a file -->
   <%
     # Use a scalar reference!
     $Response->Include(\$asp, @args);
   %>

   <!-- Cookie facilities -->
   <%
     # Read cookie
     $single_value = $Request->Cookies($cookie_name);
     $hashref = $Request->Cookies($cookie_name);

     # Set cookie
     $Response->Cookies($cookie_name, $single_value);
     $Response->Cookies($cookie_name, $hash_ref);
   %>

 </html>


=head1 DESCRIPTION

=head2 What is Mungo?

Mungo is a mod_perl 1 or 2 PerlHandler module.  It allows you to 
embed Perl code directly into HTML files, using <% %> tags.

Mungo also provides Request and Response objects, similar to many ASP 
environments.  These facilities are aimed at applications needing simple, 
lightweight features.

=head2 What Mungo does:

=over 4

=item *

Allows perl to be embedded in web pages with <% %> tags.

=item *

Provides simplistic access to various aspects of the client request via a Mungo::Request object.

=item *

Provides simplistic manipulation of the response via a Mungo::Response object.

=item *

Handles query strings, post forms (urlencoded and multipart) as well as cookies. 

=back

=head2 What Mungo does not do:

=over 4

=item *

Manage sessions

=item *

XML/XSLT/etc

=back

=head2 Implementation Goals

Mungo was originally developed as a simpler, non-GPL'd Apache::ASP with far 
fewer CPAN dependencies.  It is somewhat compatible with Apache::ASP, but 
there are enough differences to warrant close attention to the docs here.

While Mungo is very simple and has a very small fetureset, the object APIs it 
does implement adhere closely to those present in Apache::ASP. So, assuming you
are not using sessions or the XML features, you should find few obstacles
in making your application run under Mungo (it could be as simple as
setting PerlHandler Mungo in your httpd.conf file).

=cut


#=============================================================================#
#                           Implementation Notes
#=============================================================================#
# - public methods are CamelCase
# 
#=============================================================================#

use strict;
use IO::File;
eval "
  use Apache2::RequestRec;
  use Apache2::RequestUtil;
  use Apache2::Const qw ( OK NOT_FOUND );
";
if($@) {
  print STDERR "mod_perl2 not found: $@";
  eval "
    use Apache;
    use Apache::Constants qw( OK NOT_FOUND );
  ";
  die $@ if $@;
}
use MIME::Base64 qw/encode_base64 decode_base64/;
use Data::Dumper;
use Digest::MD5 qw/md5_hex/;
use Mungo::Request;
use Mungo::Response;
use Mungo::Error;
use HTML::Entities;
use Encode;

use vars qw/$VERSION
            $DEFAULT_POST_BLOCK $DEFAULT_POST_MAX_SIZE
            $DEFAULT_POST_MAX_PART $DEFAULT_POST_MAX_IN_MEMORY/;

my $SVN_VERSION = 0;
$SVN_VERSION = $1 if(q$LastChangedRevision: 301 $ =~ /(\d+)/);
$VERSION = "1.0.0.${SVN_VERSION}";

$DEFAULT_POST_BLOCK = 1024*32;          # 32k
$DEFAULT_POST_MAX_SIZE = 0;             # unlimited post size
$DEFAULT_POST_MAX_PART = 0;             # and part size
$DEFAULT_POST_MAX_IN_MEMORY = 1024*128; # 128k

=head1 MODPERL HANDLER

  PerlHandler Mungo

When Mungo is the registered handler for a URL, it first locates the file (if
not found, apache's 404 response mechanism is triggered).  Global objects
describing the transaction are created: $Request, $Server, and $Response 
(see Mungo::Response, etc. for details) Next, the file is parsed and 
evaluated, and the results are sent to the browser. This happens using $Request->Include().

=cut

sub handler($$) {
  my ($self, $r) = @_;
  if (ref $self eq 'Apache2::RequestRec') {
    $r = $self;
    $self = __PACKAGE__;
  }
  # Short circuit if we can't find the file.
  return NOT_FOUND() if(! -r $r->filename);

  $self = $self->new($r) unless(ref $self);
  $self->Response()->start();
  local $SIG{__DIE__} = \&Mungo::MungoDie;
  eval {
    $main::Request = $self->Request();
    $main::Response = $self->Response();
    $main::Server = $self->Server();
    $self->Response()->Include($r->filename);
  };
  if($@) {
    # print out the error to the logs
    print STDERR $@ if($@);
    # If it isn't too late, make this an internal server error
    eval { $self->Response()->{Status} = 500; };
  }

  # gotos come here from:
  #   $Response->End()
 MUNGO_HANDLER_FINISH:
  $self->Response()->finish();

  $self->cleanse();
  undef $main::Request;
  undef $main::Response;
  undef $main::Server;
  undef $self;
  return &OK;
}


sub MungoDie {
  my $i = 0;
  my @callstack;
  while(my @callinfo = caller($i++)) {
    push @callstack, \@callinfo;
  }
  die Mungo::Error->new({ error => shift, callstack => \@callstack });
}

=for private_developer_docs

=head2 $mungo = Mungo->new($req);

Given an Apache2::RequestRec or Apache request object,
return the Mungo context, which is a Singleton.

Called from the modperl handler.

=cut

sub new {
  my ($class, $r) = @_;
  my $self = $r->pnotes(__PACKAGE__);
  return $self if($self);
  $self = bless {
    'Apache::Request' => $r,
  }, $class;
  $r->pnotes(__PACKAGE__, $self);
  return $self;
}

sub DESTROY { }

=for private_developer_docs

=head2 $mungo->cleanse();

Releases resources at the end of a request.

=cut

sub cleanse {
  my $self = shift;
  $self->Response()->cleanse();
  $self->Request()->cleanse();
  delete $self->{'Apache::Request'};
}

# Axiomatic "I am myself"
sub Server { return $_[0]; }
sub Request { return Mungo::Request->new($_[0]); }
sub Response { return Mungo::Response->new($_[0]); }

=head2 $encoded = $mungo->URLEncode($string);

=head2 $encoded = Mungo->URLEncode($string);

Encodes a string to escape characters that are not permitted in a URL.

=cut

sub URLEncode {
  my $self = shift;
  my $s = shift;
  $s =~ s/([^a-zA-Z0-9])/sprintf("%%%02x", ord($1))/eg;
  return $s;
}

=head2 $string = $mungo->URLDecode($encoded);

=head2 $string = Mungo->URLDecode($encoded);

Decodes a string to unescape characters that are not permitted in a URL.

=cut

sub URLDecode {
  my $self = shift;
  my $s = shift;
  $s =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/eg;
  return $s;
}
sub HTMLEncode {
  my $self = shift;
  my $s = shift;
  return HTML::Entities::encode_entities( $s );
}
sub HTMLDecode {
  my $self = shift;
  my $s = shift;
  return HTML::Entities::decode_entities( $s );
}


# Private?
sub demangle_name {
  my $self = shift;
  my $name = shift;
  if($name =~ /Mungo::FilePage::([^:]+)::__content/) {
    my $filename = decode_base64($1);
    my $r = $self->{'Apache::Request'};
    if(UNIVERSAL::can($r, 'document_root')) {
      my $base = $r->document_root();
      $filename =~ s/^$base//;
    }
    $name = "Mungo::FilePage($filename)";
  }
  elsif($name =~ /Mungo::MemPage::([^:]+)::__content/) {
    $name = 'Mungo::MemPage(ANON)';
  }
  return $name;
}

# Private?
sub filename2packagename {
  my ($self, $filename) = @_;
  my $type = ref $self;
  $type =~ s/::(?:File|Mem)Page::[^:]+$//;
  my $pkg = $type . "::FilePage::" . encode_base64($filename);
  $pkg =~ s/(\s|=*$)//gs;
  return $pkg;
}
sub contents2packagename {
  my($self, $contents) = @_;
  my $type = ref $self;
  $type =~ s/::(?:File|Mem)Page::[^:]+$//;
  return $type . "::MemPage::" . md5_hex( encode_utf8($$contents) );
}


# $output = $mungo->include_mem( 
#
sub include_mem {
  my $self = shift;
  my $contents = shift;
  my $pkg = $self->contents2packagename($contents);

  unless(UNIVERSAL::can($pkg, 'content')) {
    return unless $self->packagize($pkg, $contents);
    # The packagize was successful, make content do __content
    eval "*".$pkg."::content = \\&".$pkg."::__content;";
  }
  my %copy = %$self;
  my $page = bless \%copy, $pkg;
  $page->content(@_);
}
# Private?
sub include_file {
  my $self = shift;
  my $filename = shift;
  if($filename !~ /^\//) {
    my $dir = $self->{'Apache::Request'}->filename;
    $dir =~ s/[^\/]+$//;
    $filename = "$dir$filename";
  }
  my $pkg = $self->filename2packagename($filename);
  my ($inode, $mtime);
  if($self->{'Apache::Request'}->dir_config('StatINC')) {
    ($inode, $mtime) = (stat($filename))[1,9];
  }
  unless(UNIVERSAL::can($pkg, 'content') &&
         $inode == eval "\$${pkg}::Mungo_inode" &&
         $mtime == eval "\$${pkg}::Mungo_mtime") {
    my $contents;
    my $ifile = IO::File->new("<$filename");
    die "$!: $filename" unless $ifile;
    {
      local $/ = undef;
      $contents = <$ifile>;
    }
    return unless $self->packagize($pkg, \$contents);
    # The packagize was successful, make content do __content
    eval "*${pkg}::content = \\&${pkg}::__content";
    # Track what we just compiled
    eval "\$${pkg}::Mungo_inode = $inode";
    eval "\$${pkg}::Mungo_mtime = $mtime";
  }
  my %copy = %$self;
  my $page = bless \%copy, $pkg;
  $page->content(@_);
}
# Private?
sub packagize {
  my $self = shift;
  my $pkg = shift;
  my $contents = shift;
  my $expr = convertStringToExpression($contents);
  my $type = ref $self;
  $type =~ s/::(?:File|Mem)Page::[^:]+$//;

  # We build a package with a __content method.  Why?
  # If this fails miserably, there is still a possibility that
  # UNIVERSAL::can($pkg, 'content') will be true, so we make __content
  # and if it all works out, we *$pkg::content = \&$pkg::__content

  my $preamble = "package $pkg;" . q^
    use vars qw/@ISA $Mungo_inode $Mungo_mtime/;
    @ISA = qw/^. $type . q^/;
    sub __content {
      my $self = shift;
      my $Request = $self->Request();
      my $Response = $self->Response();
      my $Server = $self->Server();
^;
  my $postamble = q^
    }
    1;
    ^;

  # Set these before we attempt to compile so that if there is an error,
  # we can get access to the code from somewhere else.
  eval "\$${pkg}::Mungo_preamble = \$preamble;";
  eval "\$${pkg}::Mungo_postamble = \$postamble;";
  eval "\$${pkg}::Mungo_contents = \$contents;";

  eval $preamble . $expr . $postamble;
  if($@) {
    my $error = $@;
    if(ref $error ne 'HASH') {
      my $i = 0;
      my @callstack;
      while(my @callinfo = caller($i++)) {
        push @callstack, \@callinfo;
      }
      $error = { error => $error, callstack => \@callstack };
    }
    my ($line) = ($error->{error} =~ /line (\d+)/m);
    unshift @{$error->{callstack}},
      [
        $pkg, '(ASP include)', $line
      ];
    local $SIG{__DIE__} = undef;
    die $error;
  }
  return 1;
}


sub convertStringToExpression {
  my $string_ref = shift;
  my $string = $$string_ref;
  sub __string_as_print {
    return '' unless(length($_[0]));
    my $s = Dumper($_[0]);
    substr($s, 0, 7) = 'print';
    return $s;
  }
  # The first is needed b/c variable with look-behind assertions don't work
  my $tmp;
  ($tmp = $string) =~ s/^/# /mg;
  $string =~ s/^(.*?)(?=<%|$)/__string_as_print($1)/se;
  # Replace non-code
  $string =~ s/(?<=%>)(?!<%)(.*?)(?=<%|$)/__string_as_print($1)/seg;
  # fixup code
  $string =~ s/
                <%(=?)(.*?)%>
              /
              $1 ?
                "print $2;" :           # This is <%= ... %>
                "$2;"                   # This is <% ... %>
              /sexg;
  return $string;
}

=head1 LIMITATIONS/BUGS

=over 4

=item *

Cannot define subroutines in ASP pages.  Bad things will happen.

=item *

Documentation is spotty.  This is being worked on.

=back

=head1 LICENSE INFORMATION

Copyright (c) 2007 OmniTI Computer Consulting, Inc. All rights reserved.
For information on licensing see:

https://labs.omniti.com/mungo/trunk/LICENSE

=head1 PROJECT WEBSITE

https://labs.omniti.com/trac/mungo/

=head1 AUTHOR

Theo Schlossnagle (code)

Clinton Wolfe (docs)

=cut


1;
