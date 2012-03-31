use inc::Module::Install;

name q(Mojolicious-Plugin-Cloudinary);
all_from q(lib/Mojolicious/Plugin/Cloudinary.pm);

requires q(Mojolicious) => 2.65;

test_requires q(Test::More) => 0.90;

bugtracker q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=Mojolicious-Plugin-Cloudinary);
homepage q(http://search.cpan.org/dist/Mojolicious-Plugin-Cloudinary);
repository q(git://github.com/jhthorsen/mojolicious-plugin-cloudinary);

auto_install;
WriteAll;
