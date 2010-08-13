<% my $stuff = 'mungo-output' %>

<%

=for should-be-ignored

$stuff = 'should-not-be-seen';

=cut

%>

<%= $stuff %>
