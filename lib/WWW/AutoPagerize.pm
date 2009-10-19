package WWW::AutoPagerize;
use strict;
use warnings;
use base 'Class::Accessor::Fast';
use HTML::TreeBuilder::XPath;
use JSON::Any;
use URI;
use Carp;

our $VERSION = '0.01';
our $DEBUG;

our $SiteInfo;

__PACKAGE__->mk_accessors(
    qw(ua tree next_uri responses)
);

sub _SITE_INFO {
    my $self = shift;

    $SiteInfo ||= do {
        my $res = $self->ua->get('http://wedata.net/databases/AutoPagerize/items.json');
        die $res->message if $res->is_error;
        my $json = JSON::Any->new->from_json($res->content);
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

    $self->responses([]);

    unless ($self->ua) {
        require LWP::UserAgent;
        my $ua = LWP::UserAgent->new(agent => __PACKAGE__ . '/' . $VERSION);
        $self->ua($ua);
    }

    $args{response} ||= $self->ua->get($args{uri})
        or croak 'response or uri required';

    $self->push_response($args{response});
    $self->tree($self->parse_response);
    $self->update_next_uri unless $self->next_uri;
}

sub push_response {
    my $self = shift;
    my $response = shift;

    push @{ $self->responses }, $response;
}

sub response {
    my $self = shift;
    $self->responses->[-1];
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
        or warn 'Reached at end' and return;
    warn "next_uri: $next_uri" if $DEBUG;

    my $next_res = $self->ua->get($next_uri);
    $self->push_response($next_res);

    my $next_tree = $self->parse_response;
    my @next_page_elements = @{ $next_tree->findnodes($site_info->{pageElement}) }
        or warn 'Could not find next page\'s pageElement' and return;
    
    $self->update_next_uri(tree => $next_tree);

    # TODO 共通の親を探す
    $page_elements[0]->parent->push_content(@next_page_elements);
}

sub update_next_uri {
    my ($self, %args) = @_;
    my $site_info = $args{site_info} || $self->site_info;
    my $tree      = $args{tree}      || $self->tree;

    my $node = $tree->findnodes($site_info->{nextLink})->[0] or return;
    my $uri  = $node->attr('href') or return;
       $uri  = URI->new_abs($uri, $self->uri);
    $self->next_uri($uri);
}

sub site_info {
    my $self = shift;
    $self->{site_info} ||= $self->find_site_info;
}

sub find_site_info {
    my $self = shift;
    foreach (@{ $self->_SITE_INFO }) {
        return $_ if $self->uri =~ /$_->{url}/ && $self->update_next_uri(site_info => $_);
    }
}

sub parse_response {
    my $self = shift;
    _parse_content($self->response->decoded_content || $self->response->content);
}

sub _parse_content {
    my ($content) = @_;
    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse($content);
    $tree->eof;
    $tree;
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
