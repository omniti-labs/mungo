<% #> -*-cperl-*-

  use Data::Dumper;

  my $handler = sub {
     my $txt = shift;
     my $langs = shift;
     print Data::Dumper->Dump([$langs], ['got']);
     return $txt;
  };

  $Response->i18nHandler($handler);

%>
<%= $Response->i18n('') %>
