package Audio::SunVox::FFI::Slot;

# ABSTRACT: Object representing a SunVox Slot.

use strict;
use warnings;

our $VERSION = '0.00';

use Carp qw/ carp croak /;
use Audio::SunVox::FFI ':all';
use Audio::SunVox::FFI::Module;
use Audio::SunVox::FFI::ModuleData;

my $slot = -1;
my $first;
my $last;

our $audiodriver;
our $audiodevice;
our $buffer;
our $samplerate = 48_000;
our $channels = 2;
our $flags = 0;
our $quiet;

use namespace::clean;

sub import {
    my ( $pkg, %cfg ) = @_;
    $audiodriver = $cfg{ audiodriver } if $cfg{ audiodriver };
    $audiodevice = $cfg{ audiodevice } if $cfg{ audiodevice };
    $buffer      = $cfg{ buffer }      if $cfg{ buffer };
    $samplerate  = $cfg{ samplerate }  if $cfg{ samplerate };
    $channels    = $cfg{ channels }    if $cfg{ channels };
    $flags       = $cfg{ flags }       if $cfg{ flags };
    $quiet       = $cfg{ quiet }       if $cfg{ quiet };
}

sub DESTROY {
    my ( $self ) = @_;
    # TODO: save .sunvox file here
}

sub _init {
    my ( %params ) = @_;

    my $_audiodriver = $params{ audiodriver } // $audiodriver;
    my $_audiodevice = $params{ audiodevice } // $audiodevice;
    my $_buffer      = $params{ buffer }      // $buffer;
    my $_samplerate  = $params{ samplerate }  // $samplerate;
    my $_channels    = $params{ channels }    // $channels;
    my $_flags       = $params{ flags }       // $flags;

    my @config;
    push @config, "audiodriver=$_audiodriver" if $_audiodriver;
    push @config, "audiodevice=$_audiodevice" if $_audiodevice;
    push @config, "buffer=$_buffer" if $_buffer;

    $_flags |= SV_INIT_FLAG_NO_DEBUG_OUTPUT if $params{ quiet } || $quiet;
    my $init = 0;
    $init = sv_init( join( '|', @config ), $_samplerate, $_channels, $_flags ) if ! $Audio::SunVox::FFI::initialised;
    croak "Error initialising : $init" if $init < 0;
}

sub new {
    my ( $class, %params ) = @_;

    $slot++;
    croak "No more slots available" if $slot > 15;

    _init( %params );

    $params{ num } = $slot;
    sv_open_slot( $slot );

    my $self = bless \%params, $class;
    $first //= $self;
    $last = $self;
}

sub lock   { sv_lock_slot( shift->num ) }
sub unlock { sv_unlock_slot( shift->num ) }

sub add_module {
    my ( $self, $type, $name ) = @_;
    $name //= $type . int rand(999_999);
    $self->lock;
    # TODO: Something better than rand. Could probably arrange modules in a grid.
    my $module = sv_new_module( $self->num, $type, $name, int rand( 1024 ), int rand( 1024 ) );
    $self->unlock;
    croak "Unable to create module $type!" unless $module;
    $module;
}

sub remove_module {
    my ( $self, $module ) = @_;
    $self->lock;
    sv_remove_module( $self->num, $module->num );
    $self->unlock;
}

sub remove_pattern {
    my ( $self, $pattern ) = @_;
    $self->lock;
    sv_remove_pattern( $self->num, $pattern->num );
    $self->unlock;
}

sub add_pattern {
    my ( $self, $tracks, $lines, $name, $clone, $x, $y, $seed ) = @_;
    $tracks //= 4;
    $lines //= 32;
    $clone //= -1;
    $seed //= int rand( 2_147_483_648 );
    $x //= int rand( 1_024 );
    $y //= int rand( 1_024 );
    $name //= 'Pattern' . int rand( 999_999 );
    $self->lock;
    my $pattern = sv_new_pattern( $self->num, );
    $self->unlock;
    $pattern;
}

sub number_of_patterns {
    my ( $self ) = @_;
    sv_get_number_of_patterns( $self->num );
}

sub num { shift->{ num } }

sub get_first {
    $first //= shift->new;
}
*first = \&get_first;

sub get_last {
    $last //= shift->new;
}
*last = \&get_last;

sub save {
    my ( $self, $filename ) = @_;
    sv_save( $self->num, $filename );
}

sub load {
    my ( $self, $filename ) = @_;
    sv_load( $self->num, $filename );
}

sub audio_callback { ... }
sub audio_callback2 { ... }

sub play {
    my ( $self ) = @_;
    sv_play( $self->num );
}

sub play_from_beginning {
    my ( $self ) = @_;
    sv_play_from_beginning( $self->num );
}

sub pause {
    my ( $self ) = @_;
    sv_pause( $self->num );
}

sub resume {
    my ( $self ) = @_;
    sv_resume( $self->num );
}

sub sync_resume {
    my ( $self ) = @_;
    sv_sync_resume( $self->num );
}

sub autostop {
    my ( $self, $autostop ) = @_;
    return sv_get_autostop( $self->num ) unless defined $autostop;
    $autostop = $autostop ? 1 : 0;
    sv_set_autostop( $self->num, $autostop );
}

sub end_of_song {
    my ( $self ) = @_;
    sv_end_of_song( $self->num );
}

sub rewind {
    my ( $self, $line ) = @_;
    $line //= 0;
    sv_rewind( $self->num, $line );
}

sub volume {
    my ( $self, $vol ) = @_;
    sv_volume( $self->num, $vol );
}

sub mute { shift->volume( 0 ); }

sub current_line {
    my ( $self ) = @_;
    sv_get_current_line( $self->num );
}

# TODO: Add fixed point wrapper to FFI lib
sub current_line2 { ... }

sub current_signal_level {
    my ( $self, $channel ) = @_;
    sv_get_current_signal_level( $self->num, $channel );
}

sub name {
    my ( $self, $name ) = @_;
    return sv_set_song_name( $self->num, $name ) if defined $name;
    sv_get_song_name( $self->num );
}

sub bpm {
    my ( $self ) = @_;
    sv_get_song_bpm( $self->num );
}

sub tpl {
    my ( $self ) = @_;
    sv_get_song_tpl( $self->num );
}

sub length_frames {
    my ( $self ) = @_;
    sv_get_song_length_frames( $self->num );
}

sub length_lines {
    my ( $self ) = @_;
    sv_get_song_length_lines( $self->num );
}

sub time_map {
    my ( $self, $start_line, $len, $flags ) = @_;
    sv_get_time_map( $self->num, $start_line, $len, $flags );
}

sub time_map_speed {
    my ( $self, $start_line, $len ) = @_;
    map { ( $_ & 0xFFFF, $_ >> 16 & 0xFFFF ) } ( sv_get_time_map( $self->num, $start_line, $len, SV_TIME_MAP_SPEED ) );
}

sub time_map_framecnt {
    my ( $self, $start_line, $len ) = @_;
    sv_get_time_map( $self->num, $start_line, $len, SV_TIME_MAP_FRAMECNT );
}

sub event_t {
    my ( $self, $set, $t ) = @_;
    sv_set_event_t( $self->num, $set, $t )
}

sub module_type {
    my ( $self, $module ) = @_;
    my $num = ref $module
        ? $module->num
        : $module;
    sv_get_module_type( $self->num, $num );
}

sub load_module {
    my ( $self, $filename ) = @_;
    my $module = sv_load_module( $self->num, $filename, int rand( 1024 ), int rand( 1024 ) );
    my $type = $self->module_type( $module );
    return $module > 0 # NO
        ? Audio::SunVox::FFI::ModuleData::_class_name( $type )->new( in_slot => 1, slot => $self, num => $module )
        : undef;
}

sub number_of_modules {
    my ( $self ) = @_;
    sv_get_number_of_modules( $self->num );
}

sub find_module {
    my ( $self, $name ) = @_;
    my $module = sv_find_module( $self->num, $name );
    my $type = $self->module_type( $module );
    return $module > 0
        ? Audio::SunVox::FFI::ModuleData::_class_name( $type )->new( in_slot => 1, slot => $self, num => $module )
        : undef;
}

sub find_pattern {
    my ( $self, $name ) = @_;
    my $pattern = sv_find_pattern( $self->num, $name );
    Audio::SunVox::FFI::Pattern->new( in_slot => 1, slot => $self, num => $pattern );
}

sub asap {
    my ( $self ) = @_;
    sv_set_event_t( $self->num, 1, 0 );
}

sub ticks {
    sv_get_ticks();
}

sub log {
    my ( $self, $bytes ) = @_;
    sv_get_log( $bytes );
}

1;
