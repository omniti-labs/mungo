<%
my $file = $Server->{'Apache::Request'}->filename;
(my $dir = $file) =~ s/\/[^\/]*$//;
opendir(D, $dir);
my @files = sort grep /(?<!index)\.asp$/, readdir(D);
closedir(D);
%>
<html>
<body>
<h1>Tests:</h2>
<ol>
<% foreach (@files) { %>
 <li><a href="<%= $_ %>"><%= $_ %></a></li>
<% } %>
</ol>
</body>
</html>
