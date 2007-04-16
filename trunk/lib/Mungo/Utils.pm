package Mungo::Utils;

use strict;

=pod

       The time2str function is taken from HTTP::Date,
       in the event HTTP::Date isn't available.

       Copyright 1995-1999, Gisle Aas

       This library is free software; you can redistribute it and/or modify it
       under the same terms as Perl itself.

=cut

my %MoY;
my @DoW = qw(Sun Mon Tue Wed Thu Fri Sat);
my @MoY = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
@MoY{@MoY} = (1..12);
sub time2str(;$) {
  my $time = shift;
  $time = time unless defined $time;
  my ($sec, $min, $hour, $mday, $mon, $year, $wday) = gmtime($time);
  sprintf("%s, %02d %s %04d %02d:%02d:%02d GMT",
          $DoW[$wday],
          $mday, $MoY[$mon], $year+1900,
          $hour, $min, $sec);
}
sub str2time($;$) {
  die "st2time unimplemented, install HTTP::Date\n";
}

1;
