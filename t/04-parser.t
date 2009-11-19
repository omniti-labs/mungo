# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use Apache::Test qw(-withtestmore);
use Apache::TestRequest qw(GET);
use Test::More tests => 10;

# 04-parser.t
# Goal: Confirm that the Mungo parser correctly assembles simple things in the right order.
# 

my ($url, $response, $content, $pattern);

$url = '/04-parser/';
$response = GET $url;
ok($response->is_success, "Fetch of $url should be a success");
$content = $response->content();
like($content, $pattern, "Content of $url should be correct");
unlike($content, qr{<\%}, "Content of by-ext $url should not contain mungo start tag '<\%'");
unlike($content, qr{\%>}, "Content of by-ext $url should not contain mungo end tag '\%>'");






