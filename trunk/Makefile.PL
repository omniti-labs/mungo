use ExtUtils::MakeMaker;

WriteMakefile(
  NAME            => 'Mungo',
  VERSION_FROM    => 'lib/Mungo.pm',
  PREREQ_PM       => { 'Apache' => 1.27 }
);

