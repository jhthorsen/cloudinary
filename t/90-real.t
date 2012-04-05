use warnings;
use strict;
use lib qw(lib);
use Test::More;
use Mojo::IOLoop;
use Mojolicious::Plugin::Cloudinary;

# Set MOJO_USERAGENT_DEBUG=1 if you want to see the actual
# data sent between you and cloudinary.com

plan skip_all => 'API_KEY is not set' unless $ENV{'API_KEY'};
plan skip_all => 'API_SECRET is not set' unless $ENV{'API_SECRET'};
plan skip_all => 'CLOUD_NAME is not set' unless $ENV{'CLOUD_NAME'};
plan tests => 2;

my $cloudinary = Mojolicious::Plugin::Cloudinary->new({
                     api_key => $ENV{'API_KEY'},
                     api_secret => $ENV{'API_SECRET'},
                     cloud_name => $ENV{'CLOUD_NAME'},
                 });

{
    $cloudinary->upload({
        file => { file => 't/test.jpg' },
        on_success => sub {
            my($res) = @_;
            ok(1, 't/test.jpg was uploaded');
            diag $res->{'public_id'};
            $cloudinary->destroy({
                public_id => $res->{'public_id'},
                on_success => sub {
                    ok(1, 't/test.jpg was destroyed');
                    Mojo::IOLoop->stop;
                },
                on_error => sub {
                    ok(0, 't/test.jpg could not be destroyed');
                    Mojo::IOLoop->stop;
                },
            });
        },
        on_error => sub {
            my($res, $tx) = @_;
            ok(0, 't/test.jpg could not be uploaded');
            ok(0, 't/test.jpg could not be destroyed');
            Mojo::IOLoop->stop;
        },
    });

    Mojo::IOLoop->start;
}
