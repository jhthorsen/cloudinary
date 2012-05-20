use inc::Module::Install;

name q(Cloudinary);
all_from q(lib/Cloudinary.pm);

requires q(Mojolicious) => 2.65;
requires q(base) => 2.10;

test_requires q(Test::More) => 0.90;

bugtracker q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=Cloudinary);
homepage q(http://search.cpan.org/dist/Cloudinary);
repository q(git://github.com/jhthorsen/cloudinary);

auto_install;
WriteAll;
