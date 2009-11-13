I[[Name]]: Mungo <br/>
<%= $Response->i18n('the other way') %> <br/>
I[[Telephone]]: none <br/>

<%
  $Response->i18nHandler(sub { return join('', reverse split //, shift); });
%>

I[[Name]]: Mungo <br/>
<%= $Response->i18n('the other way') %> <br/>
I[[Telephone]]: none <br/>

