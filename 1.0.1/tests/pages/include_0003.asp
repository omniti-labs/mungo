TrapInclude test, these steps should be backwards:<br />
<%

$a = "<\% my \$a = shift; %\><\%= \$a %\><br />";

my $step1 = $Response->TrapInclude(\$a, "step1");
my $step2 = $Response->TrapInclude(\$a, "step2");

print $step2;
print $step1;
%>
