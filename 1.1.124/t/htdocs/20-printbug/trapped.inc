<% #> -*-cperl-*-
	print 1,2,3,4;
	print "\n";
	local $, = "-";
	print 1,2,3,4;
%>