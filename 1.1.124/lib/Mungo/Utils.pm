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

sub pretty_print_code {
  my ($preamble, $contents, $postamble, $line) = @_;
  my $outer_line = 1;
  my $inner_line = 1;
  my $rv = '';
  my $numbered_preamble = '';
  if(defined($preamble)) {
    ($numbered_preamble = $preamble) =~
      s/^/sprintf("[ %4d]       ", $outer_line++)/emg;
    $rv .= qq^<pre style="color: #999">$numbered_preamble</pre>\n^;
  }
  (my $numbered_contents = $$contents) =~
    s/^/sprintf("[%s%4d] %4d: ", ($outer_line == $line)?'*':' ',
                $outer_line++, $inner_line++)/emg;
  $numbered_contents = HTML::Entities::encode($numbered_contents);
  $rv .= "<pre>$numbered_contents</pre>\n";
  my $numbered_postamble;
  if(defined($postamble)) {
    ($numbered_postamble = $postamble) =~
      s/^/sprintf("[ %4d]       ", $outer_line++)/emg;
    $rv .= qq^<pre style="color: #999">$numbered_postamble</pre>\n\n^;
  }
  return $rv;
}

1;
