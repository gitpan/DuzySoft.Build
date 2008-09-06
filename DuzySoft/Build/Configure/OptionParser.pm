#  Copyright (C) 2008-02-17 DuzySoft.com, All rights reserves.
#  All rights reserved by Duzy Chan<duzy@duzy.ws>
#
#  $Id: OptionParser.pm 67 2008-02-25 03:14:06Z dz $
#

=head1 NAME

DuzySoft::Build::Configure::Options::OptionParser - Parse the arguments of the
command line.

=head1 SYNOPSYS

    use DuzySoft::Build::Configure::OptionParser qw( parse_options );
    use DuzySoft::Build::Configure::Options;

    my $options = DuzySoft::Build::Configure::Options->new;
    die "Failed to parse options."
        unless parse_options( $options, \@ARGV );

=head1 DESCRIPTION

=head1 USAGE

=head2 Import Parameters

This module accepts a import parameters named C<parse_options>, this parameter
will tell the module to export the C<parse_options> subroutine.

=cut

package DuzySoft::Build::Configure::OptionParser;

require Exporter;
use base qw( Exporter );
@EXPORT_OK = qw( parse_options );

use strict;
use warnings;

sub _print_version_screen {
#    my $this = shift;

    print
        "DuzySoft::Build::Configure system, Version ",
            DuzySoft::Build::Configure::VERSION, ".\n"
                ;

    exit(1);
}

sub _print_usage_screen {
#    my $this = shift;
    my $command_line = "configure";

    print "
Usage:
    $command_line [options]

General Options:
    --help              Show this usage screen.
    --version           Prints the version information of
                        DuzySoft::Build::Configure system.

Compile Options:
    --cc=(compiler)     Specifies the C compiler
    --ccflags=(flags)   Specifies the C compiler flags
    --cxx=(compiler)    Specifies the C++ compiler
    --cxxflags=(flags)  Specifies the C++ compiler flags
    --ld=(linker)       Specifies the linker
    --ldflags=(flags)   Specifies the linker flags

";

    exit(1);
}

sub _handle_unknown_option {
    # FIXME: unknow option cannot get here.
    print "Unknown option.\n";
    _print_usage_screen;
}


=head2 Methods

=over 4

=item * C<parse_options()>

Parses the command line options.

=cut

sub parse_options {
    my ( $options, $argv ) = @_;

#     if ( ! defined $argv ) {
#         print "You should currently specify arguments to configure script.";
#         _print_usage_screen;
#         return;
#     }


#    use Getopt::Long; # qw( :config prefix );
#    my $parser = Getopt::Long::Parser->new;
#    $parser->configure( 'config: prefix' );
#    $parser->configure( $argv );

#     die "Invalid configure options."
#         unless $parser->getoptions(
#             help        => sub { $this->_print_usage_screen; },
#             version     => sub { $this->_print_version_screen; },
#             '<>'        => sub {
#                 print "unknown option";
#                 $this->_print_usage_screen;
#             },
#         );

    use Getopt::Long;
    die "Invalid configure options."
        unless GetOptions(
            help        => sub { _print_usage_screen; },
            version     => sub { _print_version_screen; },

            'abc=s'     => \$options->{abc},
            '<>'        => sub { _handle_unknown_option; },
        );
}

