package Mungo::Error;

# Copyright (c) 2007 OmniTI Computer Consulting, Inc. All rights reserved.
# For information on licensing see:
#   https://labs.omniti.com/mungo/trunk/LICENSE

use strict;

use overload
    # an exception is always true
    bool => sub { 1 },
    '""' => 'as_string',
    fallback => 1;

sub new {
  my $class = shift;
  bless shift, $class;
}

sub as_string {
  shift->{error};
}

1;
