package Mungo::MultipartFormData;

# Copyright (c) 2007-2009 OmniTI Computer Consulting, Inc. All rights reserved.
# For information on licensing see:
#   https://labs.omniti.com/mungo/trunk/LICENSE

use strict;
use Mungo;
use Mungo::Request;
use File::Temp;
use IO::File;
use Data::Dumper;
eval "use Apache2::RequestIO;";

=head2 $mpfd = Mungo::MultipartFormData->new($req, $length, $boundary);

Parses the incoming content. $req should be an Apache2::RequestRec.

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->load(@_);

    # Now merge up the parts into the hash itself, so it looks "normal"
    foreach my $part (@{$self->{parts}}) {
        if ($part->{name}) {
            my $name = $part->{name};

            if ($part->{filename}) {
                # Looks like a file.  Trim down the Part a bit.
                delete $part->{maxmem};
                delete $part->{name};

                # Prep the Part for reading as a fielhandle.
                if (exists($part->{payload}) && !exists($part->{handle})) {
                    # So we have a payload, but not a handle?  Must have been a small file.

                    # Create a new IO::Handle by opening the payload "in memory"
                    # See perldoc -f open and perldoc perliol
                    # I would MUCH rather use IO::Scalar for this - it's much saner and more clear
                    open($part->{handle}, "<", \$part->{payload}); # just threw up in my mouth a little
                    bless $part->{handle}, 'IO::Handle'; # just threw up in my mouth a lot
                    delete $part->{payload};
                }
                $part->{handle}->seek(0,0) if(UNIVERSAL::can($part->{handle}, 'seek'));

                # OK, now store the whole Part. Be careful not to stomp on duplicates.
                if (exists $self->{$name}) {
                    # We already have a param with this name.  Promote to arrayref.
                    if (ref($self->{$name}) eq 'ARRAY') {
                        push @{$self->{$name}}, $part;
                    } else {
                        # Need to make it an arrayref.
                        $self->{$name} = [ $self->{$name}, $part ];
                    }
                } else {
                    $self->{$name} = $part;
                }

            } else {
                # Doesn't look like a file upload.  Drop all Part trappings,
                # and just keep the payload.
                if (exists $self->{$name}) {
                    # We already have a param with this name.  Promote to arrayref.
                    if (ref($self->{$name}) eq 'ARRAY') {
                        push @{$self->{$name}}, $part->{payload};
                    } else {
                        # Need to make it an arrayref.
                        $self->{$name} = [ $self->{$name}, $part->{payload} ];
                    }
                } else {
                    $self->{$name} = $part->{payload};
                }
            }
        } else {
            # Drop nameless parts?
        }
    }
    delete $self->{parts};

  return $self;
}

sub load {
    my ($self, $r, $cl, $boundary) = @_;
    my $BLOCK_SIZE = $r->dir_config('PostBlockSize') || $Mungo::DEFAULT_POST_BLOCK_SIZE;
    my $MAXSIZE = $r->dir_config('PostMaxSize') || $Mungo::DEFAULT_POST_MAX_SIZE;
    my $MAXPART = $r->dir_config('PostMaxPart') || $Mungo::DEFAULT_POST_MAX_PART;
    my $MAXMEM = $r->dir_config('PostMaxInMemory') 
      || $Mungo::DEFAULT_POST_MAX_IN_MEMORY;

    # I expect to see the boundary as the first thing.. so $BLOCK_SIZE has to be
    # at least the length of boundary + CR LF
    $BLOCK_SIZE = length($boundary) + 2 unless($BLOCK_SIZE > length($boundary) + 2);

    my $bytes_read = 0;
    my $part = '';
    my $buffer = "\r\n";
    my $new_buffer = '';
    my $current_part;
    while($bytes_read < $cl) {

        # Read in a chunk
        my $to_read = ($BLOCK_SIZE < $cl - $bytes_read) ? $BLOCK_SIZE : ($cl - $bytes_read);
        $r->read($new_buffer, $to_read);
        $buffer .= $new_buffer;

        # The chunk may contain one or more inner boundaries, meaning we have 
        # reached the end of a Part.
        my $pos;
        while(($pos = index($buffer, "\r\n--$boundary\r\n")) >= 0) {
            if($current_part) {
                $current_part->append(substr($buffer, 0, $pos));
            }
            $current_part = Mungo::MultipartFormData::Part->new($MAXMEM);
            push @{$self->{parts}}, $current_part;
            # Remove the processed portion of the buffer (lvalue form of substr)
            substr($buffer, 0, $pos + length("\r\n--$boundary\r\n")) = '';
        }

        # No (more) inner boundaries in the buffer.  Make sure 
        if(!$current_part) {
            $current_part = Mungo::MultipartFormData::Part->new($MAXMEM);
            push @{$self->{parts}}, $current_part;
        }

        # The last boundary will not have a \r\n at the end.  Check for that and
        # append to the current part.
        if(($pos = index($buffer, "\r\n--$boundary--")) >= 0) {
            $current_part->append(substr($buffer, 0, $pos));
            $buffer = '';
        } elsif(length($buffer) > length("\r\n--$boundary--")) {
            # This is to make sure we leave enough to index() in the next pass
            $current_part->append(substr($buffer, 0,
                                         length($buffer) - length($boundary) - 6));
            substr($buffer, 0, length($buffer) - length($boundary) - 6) = '';
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

    # If we've already gotten so big that we store in a tempfile, just write to it.
    if (exists($self->{handle})) {
        $self->{handle}->print($buffer);
    } else {
        $self->{payload} .= $buffer;
        $self->extract_headers();
        if (length($self->{payload}) > $self->{maxmem}) {
            # We've gotten too big for our britches.
            my ($fh, $file) = tmpnam();

            # Upgrade the filehandle returned by tmpname so we can seek on it
            my $seekable;
            $seekable = IO::File->new($file, "r+") if ($fh);
            if(!$seekable) {
                print STDERR "Could not create tmpfile (for POST storage)\n";
                return undef;
            }
            $self->{handle} = $seekable;

            # Cleanup
            $fh->close();  # We're done with the fh returned by tmpname (we have a seekable version in $self->handle)
            unlink($file); # Unlink the file.  Now the only reference is our handle; when that does away, the inode will be freed.

            # OK, send the payload to the filehandle.
            $self->{handle}->print($self->{payload}) || die "cannot write to tmpfile $file";
            delete $self->{payload};

            # Next time we append, since we have $self->{handle}, we'll print immediately.
        }
    }
}

1;
