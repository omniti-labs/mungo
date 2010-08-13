<%
   $Response->AddHeader('X-mungo-test-header' => 'ponies');
%>
mungo-success
<%
   $Response->End();
%>
