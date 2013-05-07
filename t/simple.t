use warnings;
use strict;
use Test::More;
use Test::Mojo;
use Cloudinary;
use Mojolicious::Lite;
use Mojo::Asset::File;

{
    post '/v1_1/demo/image/upload', sub {
        my $c = shift;
        $c->render(json => { error => 'upload yikes!' });
    };
    post '/v1_1/demo/image/destroy', sub {
        my $c = shift;
        $c->render(json => { error => 'destroy yikes!' });
    };
}

plan tests => 6;
my $t = Test::Mojo->new;
my $cloudinary = Cloudinary->new({
                     api_key => '1234567890',
                     api_secret => 'abcd',
                     cloud_name => 'demo',
                     _api_url => '/v1_1',
                 });

{
    $cloudinary->upload(Mojo::Asset::File->new(path => $0), sub {
        my($cloudinary, $res) = @_;
        is @_, 2, 'two arguments';
        isa_ok $cloudinary, 'Cloudinary';
        is_deeply $res, { error => 'upload yikes!' }, 'uploaded';
        Mojo::IOLoop->stop;
    });
    Mojo::IOLoop->start;

    $cloudinary->destroy('sample', sub {
        my($cloudinary, $res) = @_;
        is @_, 2, 'two arguments';
        isa_ok $cloudinary, 'Cloudinary';
        is_deeply $res, { error => 'destroy yikes!' }, 'destroyed';
        Mojo::IOLoop->stop;
    });
    Mojo::IOLoop->start;
}
