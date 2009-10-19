use strict;
use warnings;
use utf8;
use Test::More tests => 4;

use WWW::AutoPagerize;

my $site_info = {
    nextLink    => '//a[@rel="prev"]',
    pageElement => 'id("days")/div',
    url         => '^https?://(?:d|[^.]+\\.g)\\.hatena\\.ne\\.jp/'
};

$WWW::AutoPagerize::SiteInfo = [ $site_info ];

my $ap = WWW::AutoPagerize->new(
    uri => 'http://d.hatena.ne.jp/motemen/',
    ua  => Fake::UA->new,
);

is $ap->next_uri, 'http://d.hatena.ne.jp/motemen/?of=5';
unlike $ap->content, qr/あ…ありのまま 今　起こった事を話すぜ！/;

$ap->load_next;
like   $ap->content, qr/あ…ありのまま 今　起こった事を話すぜ！/;

is_deeply [ map $_->base, @{ $ap->responses } ], [
    'http://d.hatena.ne.jp/motemen/',
    'http://d.hatena.ne.jp/motemen/?of=5',
];

package Fake::UA;
use base 'LWP::UserAgent';
use HTTP::Response;

sub request {
    my ($self, $req) = @_;

    my $file = $req->uri;
    $file =~ s<^https?://><>;
    $file =~ s</><->g;
    $file = "t/samples/$file";

    if (-e $file) {
        my $content = do {
            open my $fh, $file or die "Could not open $file";
            local $/;
            <$fh>;
        };
        HTTP::Response->new(200, 'OK', [], $content);
    } else {
        warn "$file not found, use HTTP";
        die;
        shift->SUPER::request(@_);
    }
}
