use warnings;
use strict;
use lib qw(lib);
use Test::More;
use Test::Mojo;
use Mojolicious::Lite;

plan tests => 14;
my $t = Test::Mojo->new('main');

{
    plugin 'Mojolicious::Plugin::Cloudinary', { cloud_name => 'test' };
    get '/image' => sub {
        my $self = shift;
        $self->render_text($self->cloudinary_image(1234567890 => { w => 50, height => 50 }, { class => 'awesome-class' }));
    };
    get '/js-image' => sub {
        my $self = shift;
        $self->render_text($self->cloudinary_js_image(1234567890 => { w => 50, height => 50 }));
    };
}

{
    $t->get_ok('/image')
        ->content_like(qr{^<img })
        ->content_like(qr{ src="http://res.cloudinary.com/test/image/upload/h_50,w_50/1234567890\.jpg"})
        ->content_like(qr{ class="awesome-class"})
        ->content_like(qr{ alt="1234567890"})
        ->content_like(qr{>$})
        ;

    $t->get_ok('/js-image')
        ->content_like(qr{^<img })
        ->content_like(qr{ src="/image/blank\.png"})
        ->content_like(qr{ class="cloudinary-js-image"})
        ->content_like(qr{ data-width="50"})
        ->content_like(qr{ data-height="50"})
        ->content_like(qr{ alt="1234567890"})
        ->content_like(qr{>$})
        ;
}
