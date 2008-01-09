package Mungo::MultipartFormData;

# Copyright (c) 2007 OmniTI Computer Consulting, Inc. All rights reserved.
# For information on licensing see:
#   https://labs.omniti.com/zetaback/trunk/LICENSE

use strict;
use Mungo;
use Mungo::Request;
use File::Temp;
use IO::File;
eval "use Apache2::RequestIO;";

package Mungo::MultipartFormData;
sub new {
  my $class = shift;
  my $self = bless {}, $class;
  $self->load(@_);

  # Now merge up the parts into the hash itself, so it looks "normal"
  foreach my $part (@{$self->{parts}}) {
    if($part->{name}) {
      if($part->{filename}) {
        $self->{$part->{name}} = $part;
        if(exists($part->{payload})) {
          open($part->{handle}, "<", \$part->{payload});
          delete $part->{payload};
        }
        $part->{handle}->seek(0,0) if(UNIVERSAL::can($part->{handle}, 'seek'));
      }
      else {
        $self->{$part->{name}} = $part->{payload};
      }
    }
    delete $part->{maxmem};
    delete $part->{name};
  }
  delete $self->{parts};
  $self;
}

sub load {
  my ($self, $r, $cl, $b) = @_;
  my $BLOCK = $r->dir_config('PostBlockSize') || $Mungo::DEFAULT_POST_BLOCK;
  my $MAXSIZE = $r->dir_config('PostMaxSize') || $Mungo::DEFAULT_POST_MAX_SIZE;
  my $MAXPART = $r->dir_config('PostMaxPart') || $Mungo::DEFAULT_POST_MAX_PART;
  my $MAXMEM = $r->dir_config('PostMaxInMemory') ||
                 $Mungo::DEFAULT_POST_MAX_IN_MEMORY;

  # I expect to see the boundary as the first thing.. so $BLOCK has to be
  # at least the length of boundary + CR LF
  $BLOCK = length($b) + 2 unless($BLOCK > length($b) + 2);

  my $bytes_read = 0;
  my $part = '';
  my $buffer = "\r\n";
  my $new_buffer = '';
  my $current_part;
  while($bytes_read < $cl) {
    my $to_read = ($BLOCK < $cl - $bytes_read) ? $BLOCK : ($cl - $bytes_read);
    $r->read($new_buffer, $to_read);
    $buffer .= $new_buffer;
    my $pos;
    while(($pos = index($buffer, "\r\n--$b\r\n")) >= 0) {
      if($current_part) {
        $current_part->append(substr($buffer, 0, $pos));
      }
      $current_part = Mungo::MultipartFormData::Part->new($MAXMEM);
      push @{$self->{parts}}, $current_part;
      substr($buffer, 0, $pos + length($b) + 6) = '';
    }
    if(!$current_part) {
      $current_part = Mungo::MultipartFormData::Part->new($MAXMEM);
      push @{$self->{parts}}, $current_part;
    }
    if(($pos = index($buffer, "\r\n--$b--")) >= 0) {
      $current_part->append(substr($buffer, 0, $pos));
      $buffer = '';
    }
    elsif(length($buffer) > length($b) + 6) {
      # This is to make sure we leave enough to index() in the next pass
      $current_part->append(substr($buffer, 0,
                                   length($buffer) - length($b) - 6));
      substr($buffer, 0, length($buffer) - length($b) - 6) = '';
    }
    $bytes_read += length($new_buffer);
  }
}

package Mungo::MultipartFormData::Part;

use strict;
use File::Temp qw/:POSIX/;

sub new {
  my $class = shift;
  my $maxmem = shift;
  return bless { payload => '', maxmem => $maxmem }, $class;
}

sub extract_headers {
  my $self = shift;
  # We already extracted out headers
  return if($self->{name});
  my $pos = index($self->{payload}, "\r\n\r\n");
  my @headers = split(/\r\n/, substr($self->{payload}, 0, $pos));
  # Consume it
  substr($self->{payload}, 0, $pos + 4) = '';
  $self->{size} = length($self->{payload});
  foreach my $header (@headers) {
    my ($k, $v) = split(/:\s+/, $header, 2);
    $self->{lc $k} = $v;
    if(lc $k eq 'content-disposition') {
      if($v =~ /^form-data;/) {
        $self->{name} = $1 if($v =~ / name="([^;]*)"/);
        $self->{filename} = $1 if($v =~ / filename="([^;]*)"/);
      }
    }
  }
}
sub append {
  my $self = shift;
  my $buffer = shift;
  $self->{size} += length($buffer);
  if(exists($self->{handle})) {
    $self->{handle}->print($buffer);
  }
  else {
    $self->{payload} .= $buffer;
    $self->extract_headers();
    if(length($self->{payload}) > $self->{maxmem}) {
      my($fh, $file) = tmpnam();
      my $seekable = IO::File->new($file, "r+") if($fh);
      if(!$seekable) {
        print STDERR "Could not create tmpfile (for POST storage)\n";
        return undef;
      }
      $fh->close();
      unlink($file);
      $self->{handle} = $seekable;
      $self->{handle}->print($self->{payload}) || die "cannot write to tmpfile";
      delete $self->{payload};
    }
  }
}

1;
