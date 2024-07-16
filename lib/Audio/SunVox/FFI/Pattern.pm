package Audio::SunVox::FFI::Pattern;

# ABSTRACT: Object representing a SunVox Pattern.

use strict;
use warnings;

our $VERSION = '0.00';

use meta;
no warnings 'meta::experimental';
my $meta = meta::get_this_package;

use Carp qw/ carp croak /;
use Audio::SunVox::FFI ':all';
use Audio::SunVox::FFI::Slot;

use namespace::autoclean;

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

my $get_dispatch = {
    name   => \&sv_set_pattern_name,
    data   => \&sv_get_pattern_data,
    size   => sub { ( sv_get_pattern_tracks( @_ ), sv_get_pattern_lines( @_ ) ) },
    xy     => sub { ( sv_get_pattern_x( @_ ), sv_get_pattern_y( @_ ) ) },
};

my $set_dispatch = {
    name => sub { sv_lock_slot( $_[0] ) ; my $r = sv_set_pattern_name( @_ ) ; sv_unlock_slot( $_[0] ); $r },
    data => sub { sv_lock_slot( $_[0] ) ; my $r = sv_set_pattern_data( @_ ) ; sv_unlock_slot( $_[0] ); $r },
    size => sub { sv_lock_slot( $_[0] ) ; my $r = sv_set_pattern_size( @_ ) ; sv_unlock_slot( $_[0] ); $r },
    xy   => sub { sv_lock_slot( $_[0] ) ; my $r = sv_set_pattern_xy( @_ ) ; sv_unlock_slot( $_[0] ); $r },
};

for my $method (qw/ name data size xy /) {
    $meta->add_symbol( "&$method", sub {
        my ( $self, @params ) = @_;
        return $set_dispatch->{ $method }->( $self->slot->num, $self->num, @params )
            if @params;
        $get_dispatch->{ $method }->( $self->slot->num, $self->num );
    } );
}

sub x {
    my ( $self, $x ) = @_;
    return $self->xy( $x, $self->y ) if defined $x;
    sv_get_pattern_x( $self->slot->num, $self->num );
}

sub y {
    my ( $self, $y ) = @_;
    return $self->xy( $self->x, $y ) if defined $y;
    sv_get_pattern_y( $self->slot->num, $self->num );
}

sub tracks {
    my ( $self, $tracks ) = @_;
    return $self->size( $tracks, $self->lines ) if defined $tracks;
    sv_get_pattern_tracks( $self->slot->num, $self->num );
}

sub lines {
    my ( $self, $lines ) = @_;
    return $self->size( $self->tracks, $lines ) if defined $lines;
    sv_get_pattern_lines( $self->slot->num, $self->num );
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
