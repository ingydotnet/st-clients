package Socialtext::WikiFixture::HTTP;
use strict;
use warnings;
use base 'Socialtext::WikiFixture';
use Encode;
use Test::More;
use Test::HTTP;
use Carp qw(croak);

=head1 NAME

Socialtext::WikiFixture::HTTP - Executes wiki tables using Test::HTTP

=cut

our $VERSION = '0.01';

=head1 DESCRIPTION

This class executes wiki tables using Test::HTTP.  Test tables
contain 3 columns:

  | *Command* | *Option1* | *Option2* |

This module will attempt to convert selenese into proper calls to
Test::HTTP.

=head1 FUNCTIONS

=head2 new( %opts )

Create a new fixture object.  Options:

=over 4

=item host

Mandatory - specifies the web server to connect to

=back

=head2 init()

Called by the constructor.  Creates a Test::HTTP object.

=cut

sub init {
    my ($self) = @_;

    $self->{http} = Test::HTTP->new;
}


=head3 handle_command()

Called by the test plan to execute each command.

=cut

sub handle_command {
    my $self = shift;
    my $sel = $self->{selenium};
    my $command = $self->_munge_command(shift);
    my ($opt1, $opt2) = $self->_munge_options(@_);

    if ($command =~ /_(?:un)?like$/) {
        if ($opt2) {
            $opt2 = $self->quote_as_regex($opt2);
        }
        else {
            $opt1 = $self->quote_as_regex($opt1);
        }
    }

    if ($self->can($command)) {
        $self->$command($opt1, $opt2);
    }
    elsif ($self->{http}->can($command)) {
        $self->{http}->$command($opt1, $opt2);
    }
    else {
        croak "Unknown command: $command";
    }
}

sub _munge_command {
    my $self = shift;
    my $command = shift;
    
    $command =~ s/-/_/g;
    return lc $command;
}

sub comment {
    my $self = shift;
    my $comment = shift;
    $self->{http}->name($comment);
}

=head2 get ( uri, accept )

GET a URI, with the specified accept type.  

accept defaults to 'text/html'.

=cut

sub get {
    my ($self, $uri, $accept) = @_;
    $accept ||= 'text/html';

    $self->_get($uri, [Accept => $accept, Cookie => $self->{_cookie}]);
}

=head2 cond_get ( uri, accept, ims, inm )

GET a URI, specifying Accept, If-Modified-Since and If-None-Match headers.

Accept defaults to text/html.

The IMS and INS headers aren't sent unless specified and non-zero.

=cut

sub cond_get {
    my ($self, $uri, $accept, $ims, $inm) = @_;
    $accept ||= 'text/html';
    my @headers = ( Accept => $accept );
    push @headers, 'If-Modified-Since', $ims if $ims;
    push @headers, 'If-None-Match', $inm if $inm;

    warn "Calling get on $uri";
    my $start = time();
    $self->{http}->get($self->{base_url} . $uri, \@headers);
    $self->{_last_http_time} = time() - $start;
}

=head2 was_faster_than ( $secs )

Tests that the previous request was faster than the supplied seconds.

=cut

sub was_faster_than {
    my ($self, $secs) = @_;

    my $elapsed = delete $self->{_last_http_time} || -1;
    cmp_ok $elapsed, '<=', $secs, "timer was faster than $secs";
}

=head2 delete ( uri, accept )

DELETE a URI, with the specified accept type.  

accept defaults to 'text/html'.

=cut

sub delete {
    my ($self, $uri, $accept) = @_;
    $accept ||= 'text/html';

    $self->_delete($uri, [Accept => $accept]);
}
=head2 code_is( code [, expected_message])

Check that the return code is correct.

=cut

sub code_is {
    my ($self, $code, $msg) = @_;
    $self->{http}->status_code_is($code);
    if ($self->{http}->response->code != $code) {
        warn "Response message: "
            . ($self->{http}->response->message || 'None')
            . " url(" . $self->{http}->request->url . ")";
    }
    if ($msg) {
        like $self->{http}->response->content(), $self->quote_as_regex($msg),
             "Status content matches";
    }
}

=head2 has_header( header [, expected_value])

Check that the specified header is in the response, with an optional second check for the header's value.

=cut

sub has_header {
    my ($self, $header, $value) = @_;
    my $hval = $self->{http}->response->header($header);
    ok $hval, "header $header is defined";
    if ($value) {
        like $hval, $self->quote_as_regex($value), "header content matches";
    }
}

=head2 post( uri, headers, body )

Post to the specified URI

=cut

sub post { shift->_call_method('post', @_) }

=head2 post_json( uri, body )

Post to the specified URI with header 'Content-Type=application/json'

=cut

sub post_json {
    my $self = shift;
    my $uri = shift;
    $self->post($uri, 'Content-Type=application/json', @_);
}

=head2 post_form( uri, body )

Post to the specified URI with header 'Content-Type=application/x-www-form-urlencoded'

=cut

sub post_form {
    my $self = shift;
    my $uri = shift;
    $self->post($uri, 'Content-Type=application/x-www-form-urlencoded', @_);
}

=head2 put( uri, headers, body )

Put to the specified URI

=cut

sub put { shift->_call_method('put', @_) }

=head2 put_json( uri, json )

Put json to the specified URI

=cut

sub put_json {
    my $self = shift;
    my $uri = shift;
    $self->put($uri, 'Content-Type=application/json', @_);
}

=head2 set_http_keepalive ( on_off )

Enables/disables support for HTTP "Keep-Alive" connections (defaulting to I<off>).

When called, this method re-instantiates the C<Test::HTTP> object that is
being used for testing; be aware of this when writing your tests.

=cut

sub set_http_keepalive {
    my $self   = shift;
    my $on_off = shift;

    # switch User-Agent classes
    $Test::HTTP::UaClass = $on_off ? 'Test::LWP::UserAgent::keep_alive' : 'LWP::UserAgent';

    # re-instantiate our Test::HTTP object
    delete $self->{http};
    $self->http_user_pass($self->{username}, $self->{password});
}

=head2 set_from_content ( name, regex )

Set a variable from content in the last response.

=cut

sub set_from_content {
    my $self = shift;
    my $name = shift || die "name is mandatory for set-from-content";
    my $regex = $self->quote_as_regex(shift || '');
    my $content = $self->{http}->response->content;
    if ($content =~ $regex) {
        if (defined $1) {
            $self->{$name} = $1;
            warn "# Set $name to '$1' from response content\n";
        }
        else {
            die "Could not set $name - regex didn't capture!";
        }
    }
    else {
        die "Could not set $name - regex ($regex) did not match $content";
    }
}

=head2 set_from_header ( name, header )

Set a variable from a header in the last response.

=cut

sub set_from_header {
    my $self = shift;
    my $name = shift || die "name is mandatory for set-from-header";
    my $header = shift || die "header is mandatory for set-from-header";
    my $content = $self->{http}->response->header($header);

    if (defined $content) {
        $self->{$name} = $content;
        warn "# Set $name to '$content' from response header\n";
    }
    else {
        die "Could not set $name - header $header not present\n";
    }
}

sub _call_method {
    my ($self, $method, $uri, $headers, $body) = @_;
    if ($headers) {
        $headers = [
            map {
                my ($k,$v) = split m/\s*=\s*/, $_;
                $k =~ s/-/_/g;
                ($k,$v);
            } split m/\s*,\s*/, $headers
        ];
    }
    $headers ||= [];
    push @$headers, Cookie => $self->{_cookie} if $self->{_cookie};
    my $start = time();
    $self->{http}->$method($self->{base_url} . $uri, $headers, $body);
    $self->{_last_http_time} = time() - $start;
}

sub _get {
    my ($self, $uri, $opts) = @_;
    warn "GET: $self->{base_url}$uri\n"; # intentional warn
    my $start = time();
    $uri = "$self->{base_url}$uri" if $uri =~ m#^/#;
    $self->{http}->get( $uri, $opts );
    $self->{_last_http_time} = time() - $start;
}

sub _delete {
    my ($self, $uri, $opts) = @_;
    my $start = time();
    $self->{http}->delete( $self->{base_url} . $uri, $opts );
    $self->{_last_http_time} = time() - $start;
}

=head2 header_isnt ( header, value )

Asserts that a header in the response does not contain the specified value.

=cut

sub header_isnt {
    my $self = shift;
    if ($self->{http}->can('header_isnt')) {
        return $self->{http}->header_isnt(@_);
    }
    else {
        my $header = shift;
        my $expected = shift;
        my $value = $self->{http}->response->header($header);
        isnt($value, $expected, "header $header");
    }
}

=head2 body_unlike ( expected )

Asserts that the response content does not contain the specified value.

=cut

sub body_unlike {
    my ($self, $expected) = @_;
    my $body = $self->{http}->response->content;

    my $re_expected = $self->quote_as_regex($expected);
    unlike $body, $re_expected,
        $self->{http}->name() . " body-unlike $re_expected";
}





=head1 AUTHOR

Luke Closs, C<< <luke.closs at socialtext.com> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-socialtext-editpage at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Socialtext-WikiTest>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Socialtext::WikiFixture::HTTP

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Socialtext-WikiTest>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Socialtext-WikiTest>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Socialtext-WikiTest>

=item * Search CPAN

L<http://search.cpan.org/dist/Socialtext-WikiTest>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2006 Luke Closs, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
