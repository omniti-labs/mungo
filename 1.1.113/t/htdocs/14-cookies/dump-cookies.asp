<% #> -*-cperl-*-
  use Data::Dumper;
%>
<%= Data::Dumper->Dump([$Request->Cookies()], ['got']); %>
