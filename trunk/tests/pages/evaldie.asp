<%

eval {
  my $a = undef;
  $a->badmethod();
};
if($@) {
  %><%= $@ %><%
}

%>
