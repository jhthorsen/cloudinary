use ExtUtils::MakeMaker;
WriteMakefile(
  NAME => 'Cloudinary',
  ABSTRACT_FROM => 'lib/Cloudinary.pm',
  VERSION_FROM => 'lib/Cloudinary.pm',
  AUTHOR => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  LICENSE => 'perl',
  PREREQ_PM => {
    'Mojolicious' => '4.30',
  },
  BUILD_REQUIRES => {
    'Test::More' => '0.90',
  },
  META_MERGE => {
    resources => {
      license => 'http://dev.perl.org/licenses/',
      homepage => 'https://metacpan.org/release/Cloudinary',
      bugtracker => 'https://github.com/jhthorsen/cloudinary/issues',
      repository => 'https://github.com/jhthorsen/cloudinary.git',
    },
  },
  test => {
    TESTS => 't/*.t',
  },
);
