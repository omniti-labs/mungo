<%

eval {
     die "mungo-success\n";
     print "mungo-failure";
};
  if($@) {
    print $@;
  } else {
    print "no exception seen";
  }

%>
