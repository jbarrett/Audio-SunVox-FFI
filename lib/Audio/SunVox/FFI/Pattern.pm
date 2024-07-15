package Audio::SunVox::FFI::Pattern;

# ABSTRACT: Object representing a SunVox Pattern.

use strict;
use warnings;

our $VERSION = '0.00';

use Carp qw/ carp croak /;
use Audio::SunVox::FFI ':all';
use Audio::SunVox::FFI::Slot;

sub new {
    my ( $class, %params ) = @_;
    $params{ slot } //= Audio::SunVox::FFI::Slot->get_last;
    my $self = bless \%params, $class;
    $self->add_to_slot( @params{ qw/ tracks lines name clone x y icon_seed /} )
        unless $self->{ in_slot };
    $self;
}

sub num { shift->{ num } }

sub slot { shift->{ slot } }

sub add_to_slot {
    my $self = shift;
    $self->{ num } = $self->slot->add_pattern( @_ );
    $self;
}

sub get_x {
    my ( $self ) = @_;
    get_pattern_x( $self->slot->num, $self->num );
}

sub get_y {
    my ( $self ) = @_;
    get_pattern_y( $self->slot->num, $self->num );
}

sub get_xy {
    my ( $self ) = @_;
    (
        get_pattern_x( $self->slot->num, $self->num ),
        get_pattern_y( $self->slot->num, $self->num ),
    )
}

sub set_xy {
    my ( $self, $x, $y ) = @_;
    sv_set_pattern_xy( $self->slot->num, $self->num, $x, $y );
}

sub get_tracks {
    my ( $self ) = @_;
    get_pattern_tracks( $self->slot->num, $self->num );
}

sub get_lines {
    my ( $self ) = @_;
    get_pattern_lines( $self->slot->num, $self->num );
}

sub get_size {
    my ( $self ) = @_;
    (
        get_pattern_tracks( $self->slot->num, $self->num ),
        get_pattern_lines( $self->slot->num, $self->num ),
    )
}

sub set_size {
    my ( $self, $tracks, $lines ) = @_;
    sv_set_pattern_size( $self->slot->num, $self->num, $tracks, $lines );
}

sub get_name {
    my ( $self ) = @_;
    get_pattern_name( $self->slot->num, $self->num );
}

sub set_name {
    my ( $self, $name ) = @_;
    set_pattern_name( $self->slot->num, $self->num, $name );
}

sub get_data {
    my ( $self ) = @_;
    get_pattern_data( $self->slot->num, $self->num );
}

sub set_data {
    my ( $self, @bytes ) = @_;
    set_pattern_data( $self->slot->num, $self->num, @bytes );
}

sub get_event {
    my ( $self, $track, $line, $col ) = @_;
    get_pattern_data( $self->slot->num, $self->num, $track, $line, $col );
}

sub set_event {
    my ( $self, $track, $line, $nn, $vv, $mm, $ccee, $xxyy ) = @_;
    set_pattern_event( $self->slot->num, $self->num, $track, $line, $nn, $vv, $mm, $ccee, $xxyy );
}

sub mute {
    my ( $self ) = @_;
    sv_pattern_mute( $self->slot->num, $self->num, 1 );
}

sub unmute {
    my ( $self ) = @_;
    sv_pattern_mute( $self->slot->num, $self->num, 0 );
}

1;
