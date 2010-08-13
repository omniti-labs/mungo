<%
  use strict;
  my $a = 1    # missing semicolon
  if ($a) {
     print "ponies!";
  }
%>
mungo-failure
