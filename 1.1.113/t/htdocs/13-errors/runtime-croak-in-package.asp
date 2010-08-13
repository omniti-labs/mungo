mungo-success
<%
   # this depends on a PerlSwitch statement in t/conf/extra-conf.in
   use MungoTest13Runtime qw(croak_in_module);

   croak_in_module();
%>
mungo_failure
