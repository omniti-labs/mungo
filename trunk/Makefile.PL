use ExtUtils::MakeMaker;
use strict;
use warnings;

use lib qw(../blib/lib lib );
use Apache::TestMM qw(test clean); #enable 'make test'

# prerequisites
my %require =
  (
   # 'Apache' => 1.27,
   "Apache::Test" => "",
   'Apache2::Const' => 2,
  );
my @scripts = qw(t/TEST);

# Require apxs option
unless (grep {$_ eq '-apxs' } @ARGV) {
    if (exists $ENV{'APXS'}) {
        push @ARGV, ('-apxs', $ENV{'APXS'});
    }
    else {
        die "You must provide the '-apxs PATH_TO_APXS' option to 'perl Makefile.PL'";
    }
}

# accept the configs from command line
Apache::TestMM::filter_args();
Apache::TestMM::generate_script('t/TEST');

WriteMakefile(
              NAME            => 'Mungo',
              VERSION_FROM    => 'lib/Mungo.pm',
              PREREQ_PM       => \%require,
              clean        => {
                               FILES => "@{ clean_files() }",
                              },
);


sub clean_files {
    return [@scripts];
}
