package Mungo;

# Copyright (c) 2007 OmniTI Computer Consulting, Inc. All rights reserved.
# For information on licensing see:
#   https://labs.omniti.com/mungo/trunk/LICENSE

use strict;
use IO::File;
use Apache;
use Apache::Constants qw( OK NOT_FOUND );
use MIME::Base64 qw/encode_base64/;
use Data::Dumper;
use Digest::MD5 qw/md5_hex/;
use Mungo::Request;
use Mungo::Response;

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

sub URLEncode {
  my $self = shift;
  my $s = shift;
  $s =~ s/([^a-zA-Z0-9])/sprintf("%%%02x", ord($1))/eg;
  return $s;
}

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
  return $type . "::MemPage::" . md5_hex($$contents);
}
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
  eval $preamble . $expr . $postamble;
  if($@) {
     print "ERROR:<br><pre>$@</pre>\n\n";
     print "PRE PARSE:<br>\n";
     my $outer_line = 1;
     my $inner_line = 1;
     (my $numbered_preamble = $preamble) =~
       s/^/sprintf("[%4d]       ", $outer_line++)/emg;
     print qq^<pre style="color: #999">$numbered_preamble</pre>\n^;
     (my $numbered_contents = $$contents) =~
       s/^/sprintf("[%4d] %4d: ", $outer_line++, $inner_line++)/emg;
     print "<pre>$numbered_contents</pre>\n";
     (my $numbered_postamble = $postamble) =~
       s/^/sprintf("[%4d]       ", $outer_line++)/emg;
     print qq^<pre style="color: #999">$numbered_postamble</pre>\n\n^;
     return 0;
  }
  return 1;
}

sub handler($$) {
  my ($self, $r) = @_;
  # Short circuit if we can't fine the file.
  return NOT_FOUND if(! -r $r->filename);

  $self = $self->new($r) unless(ref $self);
  $self->Response()->start();
  $main::Request = $self->Request();
  $main::Response = $self->Response();
  $main::Server = $self->Server();
  eval {
    $self->Response()->Include($r->filename);
  };
  if($@) {
    # If it isn't too late, make this an internal server error
    eval { $self->Response()->{Status} = 500; };
    # print out the error to the logs
    print STDERR $@ if($@);
  }
 MUNGO_HANDLER_FINISH:
  $self->Response()->finish();

  $self->cleanse();
  undef $main::Request;
  undef $main::Response;
  undef $main::Server;
 
  undef $self; 
  return &OK;
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

1;
