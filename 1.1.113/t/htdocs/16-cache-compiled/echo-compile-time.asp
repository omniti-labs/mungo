<% #> -*-cperl-*-
  use Data::Dumper;
  use Time::HiRes qw(gettimeofday);
  our $compile_time;
  BEGIN {
      $compile_time = gettimeofday();
  }

  my $info = {
              pid => $$,
              now => gettimeofday(),
              compile_time => $compile_time,
             };

  print Data::Dumper->Dump([$info],['got']);

%>
