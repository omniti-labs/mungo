#!/opt/OMNIperl/bin/perl
use strict;
use warnings;

use Mungo;

use Getopt::Long;

#=============================================================================#
#                                  INIT
#=============================================================================#

my ($SVN_VERSION) = q$Revision$ =~ /(\d+)/;
my $VERSION_NUM = "1.0.0.${SVN_VERSION}";

my $APPEND_LINE_NUMBERS = 0;
my $APPEND_FILE_NAMES = 0;
my $HELP = 0;
my $USAGE = 0;
my $SHOW_VERSION = 0;

GetOptions(
           'number-lines' => \$APPEND_LINE_NUMBERS,
           'file-names'   => \$APPEND_FILE_NAMES,
           'help'         => \$HELP,
           'usage'        => \$USAGE,
           'version'      => \$SHOW_VERSION,
          ) || usage('', 1);
if ($HELP || $USAGE) { usage('', 0); }
if ($SHOW_VERSION) { show_version(); }

my @files = @ARGV;
unless (@files) {  usage('No files specified.', 2); }

#=============================================================================#
#                               PROCESSING
#=============================================================================#

foreach my $file (@files) {
    my $mungo_string = slurp_file($file);
    my $perl_string = Mungo::convertStringToExpression(\$mungo_string);
    print $perl_string;
}

#=============================================================================#
#                              SUB SAMMICHES
#=============================================================================#

sub slurp_file {
    my $file = shift;
    unless (-e $file) {
        die "No such file or directory '$file'\n";
    }

    open(MUNGOFILE, "<$file") or die "Could not open $file: $!";
    my $line_num = 0;
    my $mungo_content = '';
    while (my $mungo_line = <MUNGOFILE>) {
        if ($APPEND_LINE_NUMBERS || $APPEND_FILE_NAMES) {
            $line_num++;
            my $append = '#' 
              . ($APPEND_FILE_NAMES ? " file $file" : '') 
                . ($APPEND_LINE_NUMBERS ? " line $line_num" : '')
                  . "\n";
            $mungo_line =~ s{\n$}{$append};
        }
        $mungo_content .= $mungo_line;
    }
    close MUNGOFILE;
    return $mungo_content;
}

sub usage {
    my $message = shift || '';
    my $exit_code = shift || 0;

    print <<EOT;
$message

$0 { --usage | --help }
  Display this message.

$0 [--number-lines] [--file-names]
   file1 [file2 ...]

  Extract Perl code from the given mungo files and print to STDOUT.

Options:
  --number-lines   Append a comment at the end of each line with the line 
                   number from the original file as '# line \\d+'
  --file-names     Append a comment at the end of each line with the 
                   filename as '# file FILENAME'.

EOT
    exit($exit_code);

}

sub show_version {
    print "$0 version " . $VERSION_NUM . "\n";
    exit(0);
}
