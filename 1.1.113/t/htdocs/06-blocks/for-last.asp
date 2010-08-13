<% 
  LOOP:
   for (1..20) { %>
<% if ($_ > 9) { last LOOP; } %>
<%= $_ %>
<% } %>
mungo-success
