QueryString Test:

<%
  my $qs_href = $Request->QueryString();
  my %qs_hash = $Request->QueryString();

  use Time::HiRes qw/gettimeofday/;
  my $now = [gettimeofday];
  srand($now->[1]);
  my $a = join('', map { ('a' .. 'z')[$_] } map {rand(26)} (1..10));
  my $b = join('', map { ('a' .. 'z')[$_] } map {rand(26)} (1..10));
  my $qs = join('&', map { "$_=" . $Server->URLEncode($qs_hash{$_}) }
                         keys %qs_hash);
%>
<a href="?<% if($qs) { print "$qs&" } %><%= $a %>=<%= $b %>">Test</a>
<pre>
<%
use Data::Dumper;

print Dumper($qs_href);
print Dumper(%qs_hash);

print "a=".$Request->QueryString('a')."\n";
%>
</pre>
