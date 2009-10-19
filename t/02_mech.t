use strict;
use warnings;
use utf8;
use Test::More;

plan skip_all => 'TEST_HTTP not set' unless $ENV{TEST_HTTP};

eval q{ use WWW::Mechanize };

plan skip_all => $@ if $@;

plan tests  => 8;

my $mech = WWW::Mechanize::AutoPagerized->new;

$mech->get('http://subtech.g.hatena.ne.jp/motemen/20090617/1245168701');
is     $mech->ap->next_uri, 'http://subtech.g.hatena.ne.jp/motemen/20090601/1243832759';
unlike $mech->content, qr<ニコ動の再生画面、最初からプレーヤーが視界に入ってるようにする userContent.css>;
unlike $mech->content, qr<autocomplpop.vim 下で iabbrev>;

$mech->ap_load_next;
is     $mech->ap->next_uri, 'http://subtech.g.hatena.ne.jp/motemen/20090317/1237292042';
like   $mech->content, qr<ニコ動の再生画面、最初からプレーヤーが視界に入ってるようにする userContent.css>;
unlike $mech->content, qr<autocomplpop.vim 下で iabbrev>;

$mech->ap_load_next;
is     $mech->ap->next_uri, 'http://subtech.g.hatena.ne.jp/motemen/20090121/1232524198';
like   $mech->content, qr<autocomplpop.vim 下で iabbrev>;

package WWW::Mechanize::AutoPagerized;
use base 'WWW::Mechanize';
use WWW::AutoPagerize;

our $AutoPagerizeLoading;

sub ap { shift->{ap} }

sub ap_load_next {
    my $self = shift;
    local $AutoPagerizeLoading = 1;
    $self->ap->load_next;
    $self->update_html($self->ap->content);
}

sub get {
    my $self = shift;

    my $res = $self->SUPER::get(@_);

    unless ($AutoPagerizeLoading) {
        $self->{ap} = WWW::AutoPagerize->new(
            response => $res,
            ua       => $self,
        );
    }

    $res;
}

sub request {
    my $self = shift;

    if ($AutoPagerizeLoading) {
        return $self->SUPER::_make_request(@_);
    } else {
        return $self->SUPER::request(@_);
    }
}

1;
