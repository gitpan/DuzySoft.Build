# Copyright (C) 2008, DuzySoft.com .
# $Id: Options.pm 58 2008-02-17 01:44:07Z duzy $

=head1 NAME

DuzySoft::Build::Configure::Options - Parses, validates and keeps the command
line options.

=head1 SYNOPSYS

    use DuzySoft::Build::Configure::Options;

    my $options = new DuzySoft::Build::Configure::Options;

    my @valid_options = @{ $options->valid_options };

    exit(1) unless $options->process( @ARGV );

    # There will be an guarantee that all options are valid till now.
    my $prefix_path = $options->get( 'prefix' );

=head1 DESCRIPTION

This module parses the command line parameters specificed to the configuration
script, and verifies the validation of the parameters, show usage screen if
failed on validation.

=head1 USAGE

=head2 Import Parameters

This module has no import/export I<symbols>;

=cut

package DuzySoft::Build::Configure::Options;

use strict;
use warnings;

use DuzySoft::Build::Configure::OptionParser qw( parse_options );

=head2 Methods

=head3 Constructor

=over

=item * C<new()>

Constructes an DuzySoft::Build::Configure::Options, returns an object of it.

=cut

my $singleton;

BEGIN {
    $singleton = {};

    bless $singleton, q{DuzySoft::Build::Configure::Options};
}

sub new {
    my $class = shift;

    return $singleton;
}

=back

=item * C<process()>

Complete the parsing and validating procedure, it will print a usage text
screen, and details all configure options.

=cut

sub process {
    my ( $this, $argv ) = @_;

    use DuzySoft::Build::Configure::OptionParser qw( parse_options );
    parse_options( $this, $argv );

    1;
}

=back

=item * C<get()>

Retrieves the specified option value.

=cut

sub get {
    my ( $this, $option_name ) = @_;

    return $this->{$option_name};
}

