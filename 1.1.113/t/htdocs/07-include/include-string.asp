
<%
   # Workaround for quoted start tag bug
   # http://labs.omniti.com/trac/mungo/ticket/17
   my $mhtml = '<' . '%= "mungo-success\n" %' . '>';
   $Response->Include(\$mhtml);
%>

