<% 
  LOOP:
   for (-2..9) { %>
<% if ($_ < 1) { next LOOP; } %>
<%= $_ %>
<% } %>
mungo-success
