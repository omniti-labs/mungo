# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use Apache::Test qw();
use Apache::TestRequest qw(GET);
use Test::More tests => 10;

# This is the Apache::Test generated index.html
# Being able to serve it just proves the test server is running.
my $url = '/index.html';
my $response = GET $url;
ok($response->is_success, "Fetch of plain HTML $url should be a success");
my $content = $response->content();
like($content, qr{welcome to localhost:(\d+)}, "Content of plain HTML should be correct");


# Test to confirm we can run an ASP file
$url = '/03-running/as-asp.asp';
$response = GET $url;
ok($response->is_success, "Fetch of by-extension $url should be a success");
$content = $response->content();
like($content, qr{passed mungo by extension}, "Fetch of  by-ext $url should be correct");
unlike($content, qr{<\%}, "Content of by-ext $url should not contain mungo start tag '<\%'");
unlike($content, qr{\%>}, "Content of by-ext $url should not contain mungo end tag '\%>'");

# Test to confirm we can run a file as Mungo regardless of extension
# Even though this ends in .html, should be treated as Mungo
$url = '/03-running/mungo/as-html.html';
$response = GET $url;
ok($response->is_success, "Fetch of by-directory $url should be a success");
$content = $response->content();
like($content, qr{passed mungo by directory}, "Content of by-dir $url should be correct");
unlike($content, qr{<\%}, "Content of by-dir $url should not contain mungo start tag '<\%'");
unlike($content, qr{\%>}, "Content of by-dir $url should not contain mungo end tag '\%>'");




