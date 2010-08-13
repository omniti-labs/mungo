<% #> -*-cperl-*-

  my $reverser = sub {
     my $txt = shift;
     return join '', reverse split(//, $txt);
  };

  $Response->i18nHandler($reverser);

%>
I[[sseccus-ognum]]
<%= $Response->i18n('sseccus-ognum') %>
