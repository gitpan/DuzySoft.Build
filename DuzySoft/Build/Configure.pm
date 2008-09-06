# Copyright (C) 2008, DuzySoft.com .
# $Id: Configure.pm 70 2008-02-28 09:25:49Z dz $

=head1 NAME

DuzySoft::Build::Configure - Conducts the Configure procedures

=head1 SYNOPSIS

    use DuzySoft::Build::Configure;

    my $conf = new DuzySoft::Build::Configure;
    my $options = $conf->options;
    # initializes options here
    # add some additional checking steps
    # add additional Makefile snippets
    #   add additional targets
    #   ...
    $conf->run;

=head1 DESCRIPTION

This module provides a means for executing of configuration.

=head1 USAGE

=head2 Import Parameters

This module accepts no arguments to its C<import> method and exports no
 I<symbols>.

=cut

package DuzySoft::Build::Configure;

use strict;
use warnings;

use Carp;

use constant {
    VERSION => q{0.1}
};

=head2 Methods

=head3 Constructor

=over4

=item * C<new()>

Accepts no arguments and returns DuzySoft::Build::Configure object.

=cut

my $singleton;

BEGIN {
    $singleton = {
        steps   => [],
        options => {},
        targets => {}, # file name as the key and dependencies as the value
    };

    bless $singleton, q{DuzySoft::Build::Configure};
}

sub new {
    my ( $class, %args ) = @_;

    my $this = $singleton;

    #confess if $class ne ref $this;
    croak "Invalid class qualifier on new" if $class ne ref $this;

    my $steps = $args{-steps};
    do {
        foreach my $step ( keys %{ $steps } ) {
            my $step_obj = _create_step_object( $step, $steps->{$step} );
            croak "Init configure failed: cannot init step" if ! $step_obj;
            push @{ $this->{steps} }, $step_obj if defined $step_obj;
        }
    } if defined $steps;

    return $this;
}

sub _create_step_object {
    my ( $step, $arg ) = @_;

    return undef if ! $step;

    my $step_obj;
    my $step_class = qq{DuzySoft::Build::Configure::Step::$step};
    eval {
        require qq{DuzySoft/Build/Configure/Step/$step.pm};
        $step_obj = $step_class->new( $arg );
    };
    croak "Init configure failed: $@" if $@;

    return $step_obj;
}

=back

=head3 Object Methods

=over 4

=item * C<options()>

Retreives the configure options specificed through the command line.

=cut

sub options {
    my $this = shift;

    return $this->{options};
}


=back

=over 4

=item * C<set_options()>

Specifies the options for the configure object.

=cut

sub set_options {
    my ( $this, $options ) = @_;

    $this->{options} = $options;
}


=back

=over 4

=item * C<run()>

Executes the configure steps.

=cut

sub run {
    my ( $this ) = @_;

    for my $step ( @{ $this->{steps} } ) {
        next if ! defined $step;

        print
            $step->name, ": ",
            $step->description, " ...\n";

        my $result = $this->_run_step( $step );

        # TODO: Check $res to see if we succeeded.
        print $step->name, ": Done, $result.\n\n";
    }
}

sub _run_step { # PRIVATE
    my ( $this, $step ) = @_;

    my $result;
    eval { $result = $step->run( $this ); };
    if ($@) {
        my $name = $step->name;
        croak "Configuration: FAILED: \n"
            . "---> $name: $@";
    }

    return $result;
}


sub add_target {
    my ( $this, %args ) = @_;
    my $name = $args{-target};
    my $valid_target_name = sub { # TODO: reimplements the varification code
        my $name = shift;
        return 0 if ! $name;
        return 1;
    };
    croak "Invalid target name: '$name'." if ! &$valid_target_name( $name );

    # REVISE: should return?
    return 0 if ! exists $args{-config};

    $this->{targets}->{$name} = $args{-config};
    return 1;
}

sub targets {
    my $this = shift;

    return keys %{ $this->{targets} };
}

sub get_target_config {
    my ( $this, $name ) = @_;

    return $this->{targets}->{$name};
}


# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:

