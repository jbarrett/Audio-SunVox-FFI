package SunVox::Test;

use Audio::SunVox::FFI ':all';
use Test2::V0;
use FFI::Platypus::Memory qw/ malloc free /;

sub call_ok { ok $_[0] >= 0, $_[1]; $_[0] }

sub init {
    call_ok sv_init( '', 48_000, 2, SV_INIT_FLAG_OFFLINE | SV_INIT_FLAG_NO_DEBUG_OUTPUT | SV_INIT_FLAG_AUDIO_INT16 ), "Initialised SunVox in offline mode";
}

sub drain {
    my $buf = malloc 16_384;
    while ( sv_audio_callback( $buf, 4_096, 0, sv_get_ticks ) != 0 ) {}
    free $buf;
}

use parent 'Exporter';
our @EXPORT = ( 't' );

sub t { __PACKAGE__ }
