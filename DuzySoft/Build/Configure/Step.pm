#
#  Copyright 2008-02-25 DuzySoft.com, by Duzy Chan
#  All rights reserved by Duzy Chan<duzy@duzy.ws>
#
#  $Id$
#

package DuzySoft::Build::Configure::Step;

use strict;
use warnings;

#checking environment   - standard environment checking, basic requirements
#scan sources           - scan sources files
#checking dependencies  - checks whether the dependencies meets the requirements
#generating makefiles   - 

sub new {
    my ( $class, $args ) = @_;

    my $this = {
        name            => undef,
        description     => undef,
    };

    do {
        $this->{name}   = $args->{-name};
        $this->{name}   = q{configure} if ! defined $this->{name};

        $this->{description} = $args->{-description};
    } if $args;

    return $this;
}

sub name {
    my $this = shift;

    return q{unnamed configure step} if ! defined $this->{name};
    return $this->{name};
}

sub description {
    my $this = shift;

    return q{} if ! defined $this->{description};
    return $this->{description};
}

1;
