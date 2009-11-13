use ExtUtils::MakeMaker;

WriteMakefile(
  NAME            => 'Mungo',
  VERSION_FROM    => 'lib/Mungo.pm',
  PREREQ_PM       => { 'Apache2::Const' => 2 }
);

