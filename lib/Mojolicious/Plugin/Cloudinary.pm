package Mojolicious::Plugin::Cloudinary;

=head1 NAME

Mojolicious::Plugin::Cloudinary - Talk with cloudinary.com

=head1 VERSION

0.02

=head1 DESCRIPTION

This module lets you interface to L<http://cloudinary.com>. Its primary
target is to be a L<Mojolicious> plugin, but it can also be used as a
generic module - just skip calling L</register>.

=head1 SYNOPSIS

=head2 With mojolicious

    package MyWebApp;
    use Mojo::Base 'Mojolicious';

    sub startup {
        my $self = shift;
        $self->plugin('Mojolicious::Plugin::Cloudinary', {
            cloud_name => $str,
            api_key => $str,
            api_secret => $str,
        });
    }

    package MyWebApp::SomeController;

    sub upload {
        my $self = shift;

        $self->render_later;
        $self->cloudinary_upload({
            file => $self->param('upload_param'),
            on_success => sub {
                my $res = shift;
                $self->render_json($res);
            },
            on_error => sub {
                my $res = shift || { error => 'Unknown' };
                $self->render_json($res);
            },
        });
    }

=head2 Standalone

    my $delay = Mojo::IOLoop->delay;
    my $cloudinary = Mojolicious::Plugin::Cloudinary->new(
                         cloud_name => '...',
                         api_key => '...',
                         api_secret => '...',
                     );

    $delay->begin;
    $cloudinary->upload({
        file => { file => $path_to_file },
        on_success => sub {
            # ...
            $delay->end;
        },
        on_error => sub {
            # ...
            $delay->end;
        },
    });

    # let's you do multiple upload() in parallel
    # just call $delay->begin once pr upload()
    # and $delay->end in each on_xxx callback
    $delay->wait;

=cut

use Mojo::Base 'Mojolicious::Plugin';
use File::Basename;
use Mojo::UserAgent;
use Mojo::Util qw/ sha1_sum url_escape /;
use Scalar::Util 'weaken';

our $VERSION = eval '0.02';
my @SIGNATURE_KEYS = qw/ callback eager format public_id tags timestamp transformation type /;

=head1 ATTRIBUTES

=head2 cloud_name

Your cloud name from L<https://cloudinary.com/console>

=head2 api_key

Your API key from L<https://cloudinary.com/console>

=head2 api_secret

Your API secret from L<https://cloudinary.com/console>

=head2 private_cdn

Your private CDN url from L<https://cloudinary.com/console>.

=cut

__PACKAGE__->attr(cloud_name => sub { die 'cloud_name is required in constructor' });
__PACKAGE__->attr(api_key => sub { die 'api_key is required in constructor' });
__PACKAGE__->attr(api_secret => sub { die 'api_secret is required in constructor' });
__PACKAGE__->attr(private_cdn => sub { die 'private_cdn is required in constructor' });
__PACKAGE__->attr(_api_url => sub { 'http://api.cloudinary.com/v1_1' });
__PACKAGE__->attr(_public_cdn => sub { 'http://res.cloudinary.com' });
__PACKAGE__->attr(_ua => sub {
    my $ua = Mojo::UserAgent->new;

    $ua->on(start => sub {
        my($ua, $tx) = @_;

        for my $part (@{ $tx->req->content->parts }) {
            my $content_type = $part->headers->content_type || '';
            $part->headers->remove('Content-Type') if $content_type eq 'text/plain';
        }
    });

    return $ua;
});

=head1 METHODS

=head2 upload

    $self->upload({
        file => $binary_str|$url, # required
        timestamp => $epoch, # time()
        public_id => $str, # optional
        format => $str, # optional
        tags => ['foo', 'bar'], # optional
        on_success => sub {
            my($res) = @_;
            # ...
        },
        on_error => sub {
            my($res, $tx) = @_;
            # ...
        },
    });

Will upload a file to L<http://cloudinary.com> using the parameters given
L</cloud_name> L</api_key> and L</api_secret>. The C<file> can be:

=over 4

=item * A hash

    { file => 'path/to/image' }

=item * A L<Mojo::Upload> object.

=item * A L<Mojo::Asset> object.

=item * A URL

=back

C<res> in callbacks will be the JSON response from L<http://cloudinary.com>
as a hash ref. It may also be C<undef> if something went wrong with the
actual HTTP POST.

See also L<https://cloudinary.com/documentation/upload_images>.

=cut

sub upload {
    my($self, $args) = @_;
    
    # TODO: transformation, eager
    $args->{'resource_type'} ||= 'image';
    $args->{'timestamp'} ||= time;

    for my $name (qw/ file on_success /) {
        defined $args->{$name}
            or die "Usage: \$self->upload({ $name => ... })";
    }

    if(ref $args->{'tags'} eq 'ARRAY') {
        $args->{'tags'} = join ',', @{ $args->{'tags'} };
    }
    if(UNIVERSAL::isa($args->{'file'}, 'Mojo::Asset')) {
        $args->{'file'} = {
            file => $args->{'file'},
            filename => $args->{'filename'} || basename($args->{'file'}->path),
        };
    }
    elsif(UNIVERSAL::isa($args->{'file'}, 'Mojo::Upload')) {
        $args->{'file'} = {
            file => $args->{'file'}->asset,
            filename => $args->{'file'}->filename,
        };
    }

    $self->_call_api(upload => $args, {
        timestamp => time,
        (map { ($_, $args->{$_}) } grep { defined $args->{$_} } @SIGNATURE_KEYS),
        file => $args->{'file'},
    });
}

=head2 destroy

    $self->destroy({
        public_id => $public_id,
        on_success => sub {
            my($res) = @_;
            # ...
        },
        on_error => sub {
            my($res, $tx) = @_;
            # ...
        },
    });

Will delete an image from cloudinary, identified by C<$public_id>.

=cut

sub destroy {
    my($self, $args) = @_;

    for my $name (qw/ public_id on_success /) {
        defined $args->{$name}
            or die "Usage: \$self->destroy({ $name => ... })";
    }

    $args->{'resource_type'} ||= 'image';

    $self->_call_api(destroy => $args, {
        public_id => $args->{'public_id'},
        timestamp => $args->{'timestamp'} || time,
        type => $args->{'type'} || 'upload',
    });
}

sub _call_api {
    my($self, $action, $args, $post) = @_;
    my $url = join '/', $self->_api_url, $self->cloud_name, $args->{'resource_type'}, $action;
    my $on_error = $args->{'on_error'} || sub {};
    my $on_success = $args->{'on_success'};
    my $headers = { 'Content-Type' => 'multipart/form-data' };

    $post->{'api_key'} = $self->api_key;
    $post->{'signature'} = $self->_api_sign_request($post);

    $self->_ua->post_form($url, $post, $headers, sub {
        my($ua, $tx) = @_;

        if($tx->success) {
            $on_success->($tx->res->json);
        }
        else {
            $on_error->($tx->res->json, $tx);
        }
    });
}

sub _api_sign_request {
    my($self, $args) = @_;
    my @query;

    for my $k (@SIGNATURE_KEYS) {
        push @query, "$k=" .url_escape $args->{$k} if defined $args->{$k};
    }

    $query[-1] .= $self->api_secret;

    sha1_sum join '&', @query;
}

=head2 url_for

    $url_obj = $self->url_for("$public_id.$format", \%args);

This method will return a public URL to the image at L<http://cloudinary.com>.
It will use L</private_cdn> or the public CDN and L</cloud_name> to construct
the URL. The return value is a L<Mojo::URL> object.

Example C<%args>:

    {
        w => 100, # width of image
        h => 150, # height of image
        secure => $bool, # use private_cdn or public cdn
    }

=cut

sub url_for {
    my $self = shift;
    my $public_id = shift or die 'Usage: $self->url_for($public_id, ...)';
    my $args = shift || {};
    my $format = $public_id =~ s/\.(\w+)// ? $1 : 'jpg';
    my $url = Mojo::URL->new(delete $args->{'secure'} ? $self->private_cdn : $self->_public_cdn);

    $url->path(join '/', grep { length }
        $self->cloud_name,
        $args->{'resource_type'} || 'image',
        $args->{'type'} || 'upload',
        join(',', map { $_ .'_' .$args->{$_} } sort keys %$args),
        "$public_id.$format",
    );

    return $url;
}

=head2 register

Adds the helpers to your controller:

=over 4

=item * cloudinary_upload

=item * cloudinary_destroy

See L</upload>.

=item * cloudinary_url_for

See L</url_for>.

=back

=cut

sub register {
    my($self, $app, $config) = @_;

    for my $k (keys %{ $config || {} }) {
        $self->$k($config->{$k}) if exists $config->{$k};
    }

    $app->helper(cloudinary_upload => sub {
        my $c = shift;
        $self->upload(@_);
    });
    $app->helper(cloudinary_destroy => sub {
        my $c = shift;
        $self->destroy(@_);
    });
    $app->helper(cloudinary_url_for => sub {
        my($c, $public_id, $args) = @_;
        my $scheme = $c->req->url->scheme || '';

        if(not defined $args->{'secure'} and $scheme eq 'https') {
            $args->{'secure'} = 1;
        }

        return  $self->url_for($public_id, $args);
    });
}

=head1 COPYRIGHT & LICENSE

See L<Oppstarter>

=head1 AUTHOR

Jan Henning Thorsen - jan.henning@oppstarter.no

=cut

1;
