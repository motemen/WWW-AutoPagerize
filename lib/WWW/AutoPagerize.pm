package WWW::AutoPagerize;
use strict;
use warnings;
use base 'Class::Accessor::Fast';
use HTML::TreeBuilder::XPath;
use JSON::Any;
use URI;

our $VERSION = '0.01';
our $DEBUG;

our $SiteInfo;

__PACKAGE__->mk_accessors(
    qw(tree uri ua uris)
);

sub new {
    my $class = shift;

    my $self = $class->SUPER::new({ @_ });
    $self->initialize(@_);

    $self;
}

sub initialize {
    my $self = shift;
    my %args = @_;

    unless ($self->ua) {
        require LWP::UserAgent;
        my $ua = LWP::UserAgent->new(agent => __PACKAGE__ . '/' . $VERSION);
        $self->ua($ua);
    }

    unless ($self->tree) {
        $self->tree(
            $self->_parse_content(
                $args{content} || $self->_get_content($self->uri)
            )
        );
    }

    $self->uris([ $self->uri ]);
}

sub load_next {
    my $self = shift;

    my $site_info = $self->site_info
        or warn 'Could not load site_info' and return;

    my @page_elements = @{ $self->tree->findnodes($site_info->{pageElement}) }
        or warn 'Could not find pageElement' and return;

    my $next_uri = $self->next_uri
        or warn 'Could not find nextLink' and return;
    warn "next_uri: $next_uri" if $DEBUG;

    my $next_tree = $self->_parse_uri($next_uri);
    my @next_page_elements = @{ $next_tree->findnodes($site_info->{pageElement}) }
        or warn 'Could not find next page\'s pageElement' and return;

    push @{ $self->uris }, $next_uri;

    # TODO 共通の親を探す
    $page_elements[0]->parent->push_content(@next_page_elements);
}

sub next_uri {
    my $self = shift;

    my $site_info = $self->site_info
        or warn 'Could not load site_info' and return;

    my $node = $self->tree->findnodes($site_info->{nextLink})->[0] or return;
    my $next_uri = $node->attr('href');
    URI->new_abs($next_uri, $self->uri);
}

sub _SITE_INFO {
    my $self = shift;

    $SiteInfo ||= do {
        my $json = JSON::Any->new->from_json(
            $self->_get_content(
                'http://wedata.net/databases/AutoPagerize/items.json'
            )
        );
        [ map $_->{data}, @$json ];
    };
}

sub site_info {
    my $self = shift;
    foreach (@{ $self->_SITE_INFO }) {
        return $_ if $self->uri =~ /$_->{url}/;
    }
}

sub content { shift->tree->as_text }

sub _parse_uri {
    my ($self, $uri) = @_;
    $self->_parse_content($self->_get_content($uri));
}

sub _parse_content {
    my ($self, $content) = @_;
    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse($content);
    $tree->eof;
    $tree;
}

sub _get_content {
    my ($self, $uri) = @_;
    warn "GET $uri" if $DEBUG;
    my $res = $self->ua->get($uri);
    die $res->message if $res->is_error;
    $res->decoded_content;
}

1;

__END__

=head1 NAME

WWW::AutoPagerize -

=head1 SYNOPSIS

  use WWW::AutoPagerize;

=head1 DESCRIPTION

WWW::AutoPagerize is

=head1 AUTHOR

motemen E<lt>motemen@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
