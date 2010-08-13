<% #> -*-cperl-*-
use Data::Dumper;

if($Request->QueryString('setcookie') eq 'issue') {
  $Response->Cookies('asptest', 'set');
  $Response->Cookies('asptest', 'Expires', 5);
}
%>
<a href="?setcookie=nope">reload</a>
<a href="?setcookie=issue">issue (for 5 seconds)</a><br />

Cookie:
<pre>
<%= Dumper($Request->Cookies('asptest')); %>
</pre>

Response Cookies:
<pre>
<%= $Response->{Cookies} %>:=<%= Dumper($Response->{Cookies}); %>
</pre>

