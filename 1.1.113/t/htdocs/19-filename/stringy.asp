<%

   my $string = "
<\%
   use Data::Dumper;
   print Data::Dumper->Dump(\[\[\$Response->CurrentFile()\]\],\['got'\]);
\%\>
";

   $Response->Include(\$string); 

%>
