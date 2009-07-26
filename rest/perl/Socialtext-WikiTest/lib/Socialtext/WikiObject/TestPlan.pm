package Socialtext::WikiObject::TestPlan;
use Moose;
use Test::More;
use Moose::Meta::Class;
extends 'Socialtext::WikiObject';

=head1 NAME

Socialtext::WikiObject::TestPlan - Load wiki pages as Test plan objects

=cut

our $VERSION = '0.03';

=head1 SYNOPSIS

  use base 'Socialtext::WikiObject::TestPlan';
  my $test_plan = Socialtext::WikiObject::TestPlan->new(
      rester => $rester,
      page => $plan_page,
      server => $test_server,
      workspace => $test_workspace,
  );
  $test_plan->run_tests;

=head1 DESCRIPTION

Socialtext::WikiObject::TestPlan fetches Wiki pages using the Socialtext 
REST API, and parses the page into a testplan object.  This class can be
subclassed to support different types of test plans.

Test Plans look for a list item at the top level of the page looking like 
this:

  * Fixture: Foo
  * Fixture: Bar

This tells the TestPlan object to use the Socialtext::WikiFixture::Foo
and Socialtext::WikiFixture::Bar roles to supply methods for this test page.
A default fixture can also be specified in the constructor.

The wiki tests are specified as tables in the top level of the page.

Test Plans can also contain links to other test plans.  If no fixture is 
found, the test plan will look for wiki links in any top level list items:

  * [This Test Plan]
  * [That Test Plan]

These pages will be loaded as TestPlan objects, and their tests will be
run as well.
 
=head1 FUNCTIONS

=head2 new( %opts )

Create a new test plan.  Options:

=over 4

=item rester

Mandatory - specifies the Socialtext::Resting object that will be used 
to load the test plan.  The rester should already have a workspace conifgured.

=item page

Mandatory - the page containing the test plan.

=cut

has 'fixture_args' => (is => 'rw', isa => 'HashRef[]');

=item fixture_args

A hashref containing arguments to pass through to the fixture constructor.

=back

=cut

has 'fixture' => (is => 'ro', isa => 'Object', lazy_build => 1);

=head2 run_tests()

Execute the tests.

=cut


sub run_tests {
    my $self = shift;

    unless ($self->{table}) {
        $self->_recurse_testplans;
        return;
    }

    my $fixture = $self->fixture;
    return unless $self->{table} and $fixture;

    $self->_raise_permissions;

    $fixture->run_test_table($self->{table});
    $fixture->stop;
}

sub _build_fixture {
    my $self = shift;

    my @fixtures;
    for (@{ $self->{items} || [] }) {
        if (/^fixture:\s*(\S+)/i) {
        }
        my $class = $1;
        $class = "Socialtext::WikiFixture::$class" unless $class =~ m/::/;
        push @fixtures, $class;
    }
    push @fixtures, $self->{default_fixture} unless @fixtures;

    $self->fixture_args->{testplan} ||= $self;

    my $base_class = 'Socialtext::WikiFixture';
    my $metaclass = Moose::Meta::Class->create_anon_class(
        superclasses => [ $base_class ],
        roles => \@fixtures,
    );
    my $fixture = $metaclass->new_object( args => $self->fixture_args );
    $fixture->init;

    return $fixture;
}

sub _raise_permissions {
    my $self = shift;
    my %browsers = (
        '*firefox' => '*chrome',
        '*iexplore' => '*iehta',
    );
    my $browser = $self->fixture_args->{browser};
    for (@{ $self->{items} || [] }) {
        if (/^highpermissions$/i and $browsers{$browser}) {
            $self->fixture_args->{browser} = $browsers{$browser};
        }
    }
}

sub _recurse_testplans {
    my $self = shift;

    for my $i (@{ $self->{items} }) {
        next unless $i =~ /^\[([^\]]+)\]/;
        my $page = $1;
        warn "# Loading test plan $page...\n";
        my $plan = $self->new_testplan($page);
        eval { $plan->run_tests };
        ok 0, "Error during test plan $page: $@" if $@;
    }
}

sub new_testplan {
    my $self = shift;
    my $page = shift;

    return Socialtext::WikiObject::TestPlan->new(
        page => $page,
        rester => $self->{rester},
        default_fixture => $self->{default_fixture},
        fixture_args => $self->fixture_args,
    );
}

1;
