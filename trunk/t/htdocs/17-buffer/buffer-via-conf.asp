<% #> -*-cperl-*-
   use Time::HiRes qw(usleep);
   my $naptime = 500_000; # in microsec

   my $wad = 'deadbeef' x 1024;

   for (1..3) {
       print "$wad$_\n";
       usleep($naptime);
   }

%>

