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
%>
</pre>
</body>
</html>
