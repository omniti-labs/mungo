<%

$a = "<\% my \$a = shift; %\><\%= \$a %\>";

$Response->Include(\$a, 'OK!');

%>
