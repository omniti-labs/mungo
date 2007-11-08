<%
use Mungo;
my $obj = bless {}, 'Mungo';

# This should explode inside Mungo, not the ASP file itself.
$obj->handler(undef);

%>
