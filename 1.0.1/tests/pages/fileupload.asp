<html>
<body>
<form method=POST enctype="multipart/form-data">
File to upload (1): <input type=file name=upfile1><br>
File to upload (2): <input type=file name=upfile2><br>
Notes about the file: <input type=text name=note><br>
<br>
<input type=submit value=Press> to upload the file!
</form>
<br />
<br />
<pre>
<%
  use Data::Dumper;
  print Dumper($a = $Request->Form());

  my $up1 = $Request->Form('upfile1');
  if($up1) {
    my $fh = $up1->{handle};
    my $length = 0;
    while(<$fh>) {
      $length += length($_);
    }
    print "Length of upfile1: $length\n";
  }
%>
</pre>
</body>
</html>
