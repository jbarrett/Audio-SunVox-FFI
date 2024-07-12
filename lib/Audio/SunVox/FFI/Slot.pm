package Audio::SunVox::FFI::Slot;

use strict;
use warnings;

use Carp qw/ carp croak /;
use Audio::SunVox::FFI ':all';

my $slot = -1;
my $first;
my $last;
my $initialised = 0;

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

sub new {
    my ( $class, %params ) = @_;

    $slot++;
    croak "No more slots available" if $slot > 15;

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

    my $init = sv_init( join( '|', @config ), $_samplerate, $_channels, $_flags ) if ! $initialised;
    croak "Error initialising : $init" if $init < 0;
    $initialised = 1;

    $params{ num } = $slot;

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

sub save {
    my ( $self, $filename ) = @_;
}

sub load {
    my ( $self, $filename ) = @_;
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

1;
