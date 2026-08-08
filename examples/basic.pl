#!/usr/bin/env perl

use strict;
use warnings;
use v5.38;

use Audio::SunVox::FFI ':all';

# Initialise
my $audiodriver = 'asio';
my $audiodevice = 1;
my $buffer      = 256;
my $frequency   = 48_000;
my $channels    = 2;
sv_init( "audiodriver=$audiodriver|audiodevice=$audiodevice|buffer=$buffer", $frequency, $channels );

# Open a "slot" - an instance of SunVox
my $slot = 0;
sv_open_slot( $slot );

# Create a "generator" oscillator
sv_lock_slot( $slot );
my $generator = sv_new_module( $slot, "Generator", "My generator name!" );
sv_connect_module( $slot, $generator, 0 ); # 0 is Output
sv_unlock_slot( $slot );

# Send an event to the generator
sv_set_event_t( $slot, 1, 0 ); # Process events in real time
sv_set_module_ctl_value( $slot, $generator, 7, 0, 2 ); # Disable sustain
sv_set_module_ctl_value( $slot, $generator, 4, 200, 2 ); # Set release
sv_send_event( $slot, 0, 50, 127, $generator + 1 );
sleep(1);

# Save the patch
sv_save( $slot, 'awesome_patch.sunvox' );

# Clean up
sv_close_slot( 0 );
sv_deinit;
