<%

$Response->{Buffer} = 1;
$Response->{ContentType} = 'text/plain';

for (1 .. 100) {
  %>Item: <%= $_ %><br /><%
}
%>
