mungo-success
<%
   # this depends on a PerlSwitch statement in t/conf/extra-conf.in
   use MungoTest13Runtime qw(die_in_module);

   die_in_module();
%>
mungo_failure
