Form Test:

<pre>
<%
use Data::Dumper;
use Time::HiRes qw/gettimeofday/;
my $now = [gettimeofday];
srand($now->[1]);
my $a = join('', map { ('a' .. 'z')[$_] } (rand(26)));
my $b = join('', map { ('a' .. 'z')[$_] } map {rand(26)} (1..10));

my $qs_href = $Request->Form();
my %qs_hash = $Request->Form();

print Dumper($qs_href);
print Dumper(%qs_hash);

print "a=".$Request->Form('a')."\n";
%>
</pre>
<form method="POST">
<% while(my($k,$v) = each %qs_hash) {
      if(ref $v) {
        foreach (@$v) { %>
<%= $k %>: <input type="text" name="<%= $k %>" value="<%= $_ %>"><br />
<%      }
      } else { %>
<%= $k %>: <input type="text" name="<%= $k %>" value="<%= $v %>"><br />
<%    }
    } %>
<%= $a %>: <input type="text" name="<%= $a %>" value="<%= $b %>"><br />
<input type="submit">
</form>
