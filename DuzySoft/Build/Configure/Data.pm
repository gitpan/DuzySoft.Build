# Copyright (C) 2008, DuzySoft.com .
# $Id: Data.pm 58 2008-02-17 01:44:07Z duzy $

=head1 NAME

=head1 SYNOPSYS

=head1 DESCRIPTION

=head1 USAGE

=head2 Import Parameters

=head2 Constructor

=cut

sub new {
    my $class = shift;

    my $this = {
        items => {},
    };

    bless $this, ref $class || $class;
    return $this;
}

=back

=head2 Methods

=item * C<get> 

=cut

sub get {
    my ( $this, $prop ) = @_;

    return $this->{items}->{$prop};
}

=cut


