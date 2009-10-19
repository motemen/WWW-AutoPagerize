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
    qw(pages ua tree)
);

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

sub new {
    my $class = shift;

    my $self = $class->SUPER::new;
    $self->initialize(@_);
    $self;
}

sub initialize {
    my $self = shift;
    my %args = @_;

    $self->pages([{}]);

    unless ($self->ua) {
        require LWP::UserAgent;
        my $ua = LWP::UserAgent->new(agent => __PACKAGE__ . '/' . $VERSION);
        $self->ua($ua);
    }

    $args{response} ||= $self->ua->get($args{uri});

    $self->response($args{response});
    $self->tree($self->_parse_response($self->response));
}

sub response {
    my $self = shift;
    $self->pages->[-1]->{response} = shift if @_;
    $self->pages->[-1]->{response};
}

sub uri {
    my $self = shift;
    $self->response->request ? $self->response->request->uri : $self->response->base;
}

sub content {
    my $self = shift;
    $self->tree->as_text;
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

    my $next_res  = $self->ua->get($next_uri);
    my $next_tree = $self->_parse_response($next_res);
    my @next_page_elements = @{ $next_tree->findnodes($site_info->{pageElement}) }
        or warn 'Could not find next page\'s pageElement' and return;

    push @{ $self->pages }, { response => $next_res, tree => $next_tree };

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

sub site_info {
    my $self = shift;
    foreach (@{ $self->_SITE_INFO }) {
        return $_ if $self->uri =~ /$_->{url}/;
    }
}

sub _parse_response {
    my ($self, $res) = @_;
    $self->_parse_content($res->decoded_content || $res->content);
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
