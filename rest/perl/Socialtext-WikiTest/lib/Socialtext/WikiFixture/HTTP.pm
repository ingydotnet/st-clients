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

Mandatory - specifies the Selenium server to connect to

=item port 

Optional - specifies the port of the HTTP server

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

    if ($self->can($command)) {
        $self->$command($opt1, $opt2);
    }
    else {
        croak "Unknown command: $command";
    }
}

sub _munge_command {
    my $self = shift;
    my $command = shift;
    
    $command =~ s/-/_/g;
    return $command;
}

our $AUTOLOAD;
sub AUTOLOAD {
    my $name = $AUTOLOAD;
    $name =~ s/.+:://;
    return if $name eq 'DESTROY';

#    warn "No method $name found - passing to selenium\n";
    my $self = shift;
    if ($self->{http}->can($name)) {
        return $self->{http}->$name(@_);
    }
    croak "No fixture method '$name' could be found.";
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

    perldoc Socialtext::WikiFixture::Selenese

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
