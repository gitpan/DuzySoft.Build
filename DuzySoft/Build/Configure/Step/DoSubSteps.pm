#
#  Copyright 2008-02-28 DuzySoft.com, by Duzy Chan
#  All rights reserved by Duzy Chan<duzy@duzy.ws>
#
#  $Id$
#

=head1 NAME

DuzySoft::Build::Configure::Step::DoSubSteps - Process sub steps.

=head2 DESCRIPTION

=cut

package DuzySoft::Build::Configure::Step::DoSubSteps;

use strict;
use warnings;

use base q[DuzySoft::Build::Configure::Step];
use DuzySoft::Build::Configure;
use Carp;

sub new {
    my ( $class, $step_list ) = @_;
    my $this = $class->SUPER::new( {
        -name           => 'DoSubSteps',
        -description    => 'process sub steps',
    } );

    $this->{steps} = [];

#     my %steps = ();
#     %steps = @{ $step_list } if $step_list;
    $step_list = [] if ! $step_list;

    my ( $stuff, $size ) = ( undef, scalar @{ $step_list } );
    for( my $n = 0; $n < $size; ++$n ) {
        my ( $step_name, $step_arg )
            = ( $step_list->[$n++], $step_list->[$n] );

        #print "substep: Init: $step_name, target=".$step_arg->{-target}."\n";

        my $step_obj = DuzySoft::Build::Configure::_create_step_object(
            $step_name, $step_arg
        );
        croak "Init configure failed: cannot init substep" if ! $step_obj;
        push @{ $this->{steps} }, $step_obj if defined $step_obj;
    }

    bless $this, $class;
    return $this;
}

sub run {
    my ( $this, $config ) = @_;

    foreach my $step ( @{ $this->{steps} } ) {
        do {
            carp "Undefined step found";
            next;
        } if ! $step;

        print
            "substep: ", $step->name, ": ",
            $step->description, " ...\n";

        my $result = $config->_run_step( $step );

        print
            "       Done, $result\n"
    }

    return "substeps finished";
}

1;
