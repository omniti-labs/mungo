You should not see an 11...<br/>
<%
for (1 .. 100) {
  %>Item: <%= $_ %><%= ($_ > 10)?" BUSTED!":"" %><br /><%
  $Response->End() if($_ >= 10);
}
%>
