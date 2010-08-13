mungo-success
<%
  for (1 .. 10) {
    %><%= $_ %><%
  $Response->End() if($_ >= 6);
}
%>
