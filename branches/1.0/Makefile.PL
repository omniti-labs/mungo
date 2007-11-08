use ExtUtils::MakeMaker;

WriteMakefile(
  NAME            => 'Mungo',
  VERSION_FROM    => 'lib/Mungo.pm',
  PREREQ_PM       => { 'IO::Scalar' => 2.103,
                       'Apache' => 1.27 }
);

