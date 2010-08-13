<% #> -*-cperl-*-
   use Time::HiRes qw(usleep);
   my $naptime = 500_000; # in microsec

   $Response->{Buffer} = 1;
   my $wad = 'deadbeef' x 1024;

   # Printing output here...
   for (1..3) {
       print "$wad$_\n";
       usleep($naptime);
   }

%>

<%
   # add a header "late"
   $Response->AddHeader('X-mungo-test-header', 'ponies');
%>
mungo-failure
