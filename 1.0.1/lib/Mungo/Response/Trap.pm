package Mungo::Response::Trap;

# Copyright (c) 2007 OmniTI Computer Consulting, Inc. All rights reserved.
# For information on licensing see:
#   https://labs.omniti.com/zetaback/trunk/LICENSE

use strict;

sub TIEHANDLE {
  my $class = shift;
  my $ref = shift;
  return bless $ref, $class;
}
sub PRINT {
  my $self = shift;
  my $output = shift;
  $$self .= $output;
}
sub PRINTF {
  my $self = shift;
  $$self .= sprintf(@_);
}
sub CLOSE {
  my $self = shift;
}
sub UNTIE { }

1;

