#!/usr/bin/env perl

use strict;
use warnings;

use Audio::SunVox::FFI qw/ SV_INIT_FLAG_OFFLINE sv_audio_callback sv_get_ticks sv_get_log /;
use Audio::SunVox::FFI::Slot;
use Audio::SunVox::FFI::Module;
use Math::Trig qw/ pi2 /;
use FFI::Platypus::Memory;

my $slot = Audio::SunVox::FFI::Slot -> new(
    samplerate  => 48_000,
    channels    => 2,
    flags       => SV_INIT_FLAG_OFFLINE,
    quiet       => 1,
);

# Uses last slot instantiated
my $gen = Generator->new;
# Drawn waveform
$gen->waveform( 4 );
$gen->connect_to( Output->new );

my @curve;
my $inc = 1 / 32;
my $t = 0;
while ( $t < 1 ) {
    push @curve, sin( pi2 * $t );
    $t += $inc;
};

$gen->curve( 0, \@curve );

# Offline mode - must fetch audio data to move timeline forward and process above events.
my $buf = malloc 16_384;
while ( sv_audio_callback( $buf, 4_096, 0, sv_get_ticks ) != 0 ) {}
free $buf;

my $filename = "generator_curve_" . time . ".sunvox";
$slot->save( $filename );

print "$filename written\n";
