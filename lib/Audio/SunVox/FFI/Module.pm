package Audio::SunVox::FFI::Module;

# ABSTRACT: Objects for SunVox Modules

use strict;
use warnings;

=encoding UTF-8

=head1 SYNOPSIS

    use Audio::SunVox::FFI::Module;
    
    # Create a generator and connect it to Output
    # (Also creates a Slot if one doesn't exist,
    #  uses the last created Slot if none specified)
    my ( $generator, $output ) = Generator->new->connect( Output->new );
    $generator->volume( 0xD0 );
    
    # Note, velocity
    $generator->note_on( 0x3F, 0x7A );
    sleep 1;
    $generator->note_off( 0x3F );

=head1 DESCRIPTION

Audio::SunVox::FFI::Module offers an OO interface to L<Audio::SunVox::FFI> modules.

=cut

use meta;
no warnings 'meta::experimental';
my $meta = meta::get_this_package;

use Carp qw/ carp croak /;
use Time::HiRes qw/ time /;
use List::Util qw/ shuffle /;

use Audio::SunVox::FFI ':all';
use Audio::SunVox::FFI::ModuleData;
use Audio::SunVox::FFI::Slot;

our $VERSION = '0.00';

my $module_data = Audio::SunVox::FFI::ModuleData::_module_data;

my $scales = {
    real => 0,
    hex  => 1,
    disp => 2,
};
our $default_scale = 'disp';

=head1 COMMON METHODS

=head2 flags

    my $flags = $module->flags;
    my $is_generator = $flags & SV_MODULE_FLAG_GENERATOR;

Returns the L<module flags|https://warmplace.ru/soft/sunvox/sunvox_lib.php#cmodflags>
for the instance.

=head2 outputs

    my $outputs = $module->outputs;

Returns the list of module numbers for modules connected to from this module.

=head2 inputs

    my $inputs = $module->outputs;

Returns the list of module numbers for modules connected to this module.

=head2 type

    my $name = $module->type;

Returns the module type, e.g. "Generator".

=head2 name

    my $name = $module->name;
    $module->name( "New name" );

Returns or sets the module's name.

=head2 xy

    my @xy = $module->xy;
    $module->xy( 666, 1337 );

Returns or sets the x and y position of the module in the patch bay.

=head2 color

    my @rgb = $module->color;
    $module->color( 101, 28, 50 );

Returns or sets the colour of the module in the patch bay, as RGB values.

=head2 finetune

    my $fine = $module->finetune;
    $module->finetune( 50 );

Returns or sets the fine tune amount. This is usually a range within: 0x00 for no effect, 0x01 for a semitone lower, 0x80 for no change, 0xFF for a semitone higher.

=head2 relnote

    my $relnote = $module->relnote;
    $module->relnote( -3 );

Set the relative note of the module in semitones. Along with finetune, this is useful for tuning sampler modules.

=head2 ctl_name

    my $ctl_name = $module->ctl_name( 1 );

Return the name of the control corresponding to its order in the SunVox interface,
e.g. for a Generator ctl 0 is "Volume", ctl 1 is "Waveform".

=head2 ctl_offset

    my $ctl_name = $module->ctl_offset( 2 );

Returns the "real" vs "displayed" offset for a given control, e.g. a Generator's
control 2 is "Panning" - a left-right balance control. Internally, this is a value
from 0 to 256. This is displayed as -128 to 128, so the offset value is -128.

=head2 ctl_group

    my $ctl_group = $module->ctl_group( 0x0C );

Return the group for the given control. This is mostly useful when creating
metamodules and configuring interface colours within SunVox.

=cut

my $dispatch = {
    flags      => \&sv_get_module_flags,
    outputs    => \&sv_get_module_outputs,
    inputs     => \&sv_get_module_inputs,
    type       => \&sv_get_module_type,
    name       => \&sv_get_module_name,
    xy         => \&sv_get_module_xy,
    color      => \&sv_get_module_color,
    finetune   => sub { my ( $finetune, $relnote ) = sv_get_module_finetune( @_ ); $finetune; },
    relnote    => sub { my ( $finetune, $relnote ) = sv_get_module_finetune( @_ ); $relnote; },
    ctl_name   => \&sv_get_module_ctl_name,
    ctl_offset => \&sv_get_module_ctl_offset,
    ctl_group  => \&sv_get_module_ctl_group,
    ctl_type   => \&sv_get_module_ctl_type,
    number_of_ctls => \&sv_get_number_of_module_ctls,
};

for my $method ( keys %{ $dispatch } ) {
    $meta->add_symbol( "&$method", sub {
        my ( $self, @params ) = @_;
        $dispatch->{ $method }->( $self->slot->num, $self->num, @params );
    } );
}

=head2 ctl_min

    my $min = $module->ctl_min( 3 );
    my $min_hex = $module->ctl_min( 3, 1 );

Return the minimum value for the specified control, with optional scale parameter.

=cut

sub ctl_min {
    my ( $self, $ctl, $scale ) = @_;
    $scale //= $self->default_scale;
    sv_get_module_ctl_min( $self->slot->num, $self->num, $ctl, $scale );
}

=head2 ctl_max

    my $max = $module->ctl_max( 3 );
    my $max_hex = $module->ctl_max( 3, 1 );

Return the maximum value for the specified control, with optional scale parameter.

=cut

sub ctl_max {
    my ( $self, $ctl, $scale ) = @_;
    $scale //= $self->default_scale;
    sv_get_module_ctl_max( $self->slot->num, $self->num, $ctl, $scale );
}

=head2 ctl_value

    $module->ctl_value( $ctl );
    $module->ctl_value( $ctl, $new_value );
    $module->ctl_value( 1 );
    $module->ctl_value( 1, 0x7F );

Uses default scale.

=cut

sub ctl_value {
    my ( $self, $ctl, $val ) = @_;
    my $scale = $self->default_scale;
    return sv_set_module_ctl_value( $self->slot->num, $self->num, $ctl, $val, $scale )
        if defined $val;
    sv_get_module_ctl_value( $self->slot->num, $self->num, $ctl, $scale );
}

=head2 ctl_value_scaled

    $module->ctl_value_scaled( $ctl, $scale );
    $module->ctl_value_scaled( $ctl, $new_value, $scale );
    $module->ctl_value_scaled( 1, 2 );
    $module->ctl_value_scaled( 1, 0x7F, 2 );

Uses passed scale.

=cut

sub ctl_value_scaled {
    my ( $self, $ctl, $val, $scale ) = ( @_ > 3 )
        ? @_
        : ( @_[0..1], undef, $_[2] );
    return sv_set_module_ctl_value( $self->slot->num, $self->num, $ctl, $val, $scale )
        if defined $val;
    sv_get_module_ctl_value( $self->slot->num, $self->num, $ctl, $scale );
}

=head2 ctl_value_{real,hex,disp}

    $module->ctl_value_disp( $ctl );
    $module->ctl_value_disp( $ctl, $new_value );
    $module->ctl_value_disp( 4, -128 );

=cut

for my $scale ( qw/ real hex disp /) {
    $meta->add_symbol( "&ctl_value_$scale" , sub {
        my ( $self, $ctl, $val ) = @_;
        my $nscale = $self->scale( $scale );
        return sv_set_module_ctl_value( $self->slot->num, $self->num, $ctl, $val, $nscale )
            if defined $val;
        sv_get_module_ctl_value( $self->slot->num, $self->num, $ctl, $nscale );
    } );
}

my $ctl_hooks = {
    polyphony => sub {
        my ( $self, $count ) = @_;
        if ( $count > @{ $self->tracks } ) {
            push @{ $self->tracks }, $self->slot->trackpool->hold( $count - @{ $self->tracks } );
        }
        elsif ( $count < @{ $self->tracks } ) {
            my @release = splice @{ $self->tracks }, $count;
            $self->track_off( $_ ) for @release;
            $self->slot->trackpool->release( @release );
        }
    }
};

sub _ctl {
    my ( $ctl, $scale ) = @_;
    my ( $min, $max, $method_name ) = @{ $ctl }{ "min_$scale", "max_$scale", 'method_name' };
    sub {
        my ( $self, $value ) = @_;

        my $hook = $ctl_hooks->{ $method_name };
        $self->$hook( $value ) if $hook;

        return sv_get_module_ctl_value( $self->slot->num, $self->num, $ctl->{ ctl_num }, $self->scale( $scale ) )
            unless defined $value;

        goto nobounds if $self->skip_bounds_checking;
        if ( $value < $min ) {
            carp "Value $value below minimum of $min for $method_name - setting to $min";
            $value = $min;
        }
        elsif ( $value > $max ) {
            carp "Value $value below maximum of $max for $method_name - setting to $max";
            $value = $max;
        }
nobounds:
        sv_set_module_ctl_value(
            $self->slot->num,
            $self->num,
            $ctl->{ ctl_num },
            $value,
            $self->scale( $scale )
        );
    }
}

sub import {
    my ( $pkg, %cfg ) = @_;
    $default_scale = $cfg{ default_scale } if $cfg{ default_scale };
    __PACKAGE__->export_to_level( 1, @_ );
}

sub module {
    my ( $slot, $type, $name ) = @_;
    my $class = $module_data->{ $type }->{ class_name };
    croak "Unknown module type : $type" unless $class;
    $slot //= Audio::SunVox::FFI::Slot->get_last;
    $class->new(
        slot => $slot,
        name => $name,
        type => $type,
    );
}

sub new {
    my ( $class, %params ) = @_;
    if ( $class eq 'Audio::SunVox::FFI::Module' ) {
        carp "Audio::SunVox::FFI::Module should not be instantiated directly";
        return -1;
    }
    $params{ slot } //= Audio::SunVox::FFI::Slot->get_last;
    $params{ tracks } = ( $params{ polyphony } && $class->can('polyphony') )
        ? $params{ slot }->trackpool->hold( $params{ polyphony } )
        : $params{ slot }->trackpool->hold( 1 );
    $params{ polyphony_strategy } //= $params{ poly_mode } // 'last';
    $params{ track_activity } = {};
    my $self = bless \%params, $class;
    $self->add_to_slot( $params{ name } ) unless $self->{ in_slot };
    $self->polyphony( $params{ polyphony } ) if $params{ polyphony } && $self->can('polyphony');
    $self;
}

sub skip_bounds_checking {
    my ( $self, $val ) = @_;
    $self->{ skip_bounds_checking } = $val if defined $val;
    $self->{ skip_bounds_checking };
}

sub exists { !! ( shift->flags & SV_MODULE_FLAG_EXISTS ) }
sub is_generator { !! ( shift->flags & SV_MODULE_FLAG_GENERATOR ) }
sub is_effect { !! ( shift->flags & SV_MODULE_FLAG_EFFECT ) }
sub is_mute { !! ( shift->flags & SV_MODULE_FLAG_MUTE ) }
sub is_solo { !! ( shift->flags & SV_MODULE_FLAG_SOLO ) }
sub is_bypassed { !! ( shift->flags & SV_MODULE_FLAG_BYPASS ) }

sub scale { $scales->{ $_[1] } }

sub num { shift->{ num } }
sub slot { shift->{ slot } }
sub tracks { shift->{ tracks } }
sub track_activity { shift->{ track_activity } }

sub default_scale { shift->scale( $default_scale ) }

sub connect_to {
    my ( $self, @modules ) = @_;
    $self->slot->lock;
    sv_connect_module( $self->slot->num, $self->num, $modules[0]->num );
    $self->slot->unlock;
    return ( $self, @modules );
}
*connect = \&connect_to;

sub disconnect {
    my ( $self, $module ) = @_;
    sv_disconnect_module( $self->num, $module->num );
}

sub send_event {
    my ( $self, $track, $note, $vel, $ctl, $val ) = @_;
    $ctl //= 0;
    sv_send_event( $self->slot->num, $track, $note, $vel, $self->num + 1, $ctl << 8, $val );
}
*event = \&send_event;

sub _sort_tracks_by_time {
    my $self = shift;
    my @tracks = @_ || @{ $self->tracks };
    sort {
        $self->track_activity->{ $a }->{ time }
        <=>
        $self->track_activity->{ $b }->{ time }
    } @tracks;
}

my $polyphony_dispatch;
$polyphony_dispatch = {
    round_robin => sub {
        my $self = shift;
        push @{ $self->tracks }, shift @{ $self->tracks };
        $self->tracks->[0];
    },
    reuse => sub {
        my ( $self, $note ) = @_;
        my ( $track ) = grep { $self->track_activity->{ $_ }->{ note } == $note } @{ $self->tracks };
        defined $track
            ? $track
            : $polyphony_dispatch->{ last }->( $note );
    },
    last => sub {
        ( shift->_sort_tracks_by_time )[0];
    },
    first => sub {
        ( shift->_sort_tracks_by_time )[-1];
    },
    rand => sub {
        ( shuffle @{ shift->tracks } )[0];
    }
};

sub get_track_for_note {
    my ( $self, $note ) = @_;
    my ( $track ) = grep { $self->track_ectivity->{ $_ }->{ note } eq $note }
        @{ $self->tracks };
    $track;
}

sub note_on {
    my ( $self, $note, $vel, $fx, $val ) = @_;
    my $track = $self->$polyphony_dispatch->{ $self->{ polyphony_strategy } }->( $note );
    @{ $self->track_activity }{ qw/ note time / } = ( $note, time );
    sv_send_event( $self->slot->num, $track, $note, $vel, $self->num + 1, $fx, $val );
}

sub note_on_with_ctl {
    my ( $self, $note, $vel, $ctl, $val ) = @_;
    $self->note_on( $note, $vel, $ctl << 8, $val );
}

sub note_off {
    my ( $self, $note ) = @_;
    my $track = $self->get_track_for_note( $note );
    return unless defined $track;
    $self->track_off( $track );
}

sub track_off {
    my ( $self, $track ) = @_;
    sv_send_event( $self->slot->num, $track, NOTECMD_NOTE_OFF );
}

sub pitch {
    my ( $self, $track, $freq, $vel ) = @_;
    # ¯\_(ツ)_/¯
    my $pitch = 30720 - ( log( $freq / 16.333984375 ) / log( 2 ) ) * 3072;
    sv_send_event( $self->slot->num, $track, NOTECMD_SET_PITCH, $vel, $self->num + 1, 0, $pitch );
}

sub remove {
    my ( $self ) = @_;
    $self->slot->remove_module( $self );
}
*delete = \&remove;

sub scope {
    my ( $self, $channel, $samples ) = @_;
    sv_get_module_scope2( $self->slot->num, $self->num, $channel, $samples );
}

# Curve -> length
my $curve_map = {
    MultiSynth       => [ 128, 257, 128 ], # note/velocity, velocity/velocity, note/pitch
    WaveShaper       => [ 256 ],           # waveshaper curve
    MultiCtl         => [ 257 ],           # multictl curve
    Generator        => [ 32 ],            # drawn waveform
    AnalogGenerator  => [ 32 ],            # drawn waveform
};

sub curve {
    my ( $self, $curve_num, $data, $length ) = @_;
    $length //= $curve_map->{ ref $self }->[ $curve_num ] // @{ $data };
    sv_module_curve( $self->slot->num, $self->num, $curve_num, $data, $length );
}

sub clone {
    my ( $self, $target ) = @_;
    my $class = ref $self;
    $target //= $class->new;
    croak "Target class '" . ref $target . "' is not a '" . $class . "'"
        unless ref $target eq $class;

    # copy controls
    my $ctls = $target->number_of_ctls;
    for my $ctl ( 0..$ctls-1 ) {
        $target->ctl_value( $self->ctl_value );
    }

    # copy curves
    my @curves = @{ $curve_map->{ $class } };
    if ( @curves ) {
        for my $curve ( 0..$#curves ) {
            $target->curve( $curve, [ $self->curve( $curve ) ] );
        }
    }

    # copy other attributes
    $target->name( $self->name );
    $target->xy( $self->xy );
    $target->color( $self->color );
    $target->finetune( $self->finetune );
    $target->relnote( $self->relnote );
    $target->color( $self->color );

    $target;
}

sub clone_to_slot {
    my ( $self, $slot ) = @_;
    croak "Missing required paramater: slot" unless $slot;
    my $class = ref $self;

    my $target = $slot->add_module( $class );

    $self->clone( $target );
}

sub move_to_slot {
    my ( $self, $slot ) = @_;

    my $target = $self->clone_to_slot( $slot );

    $self->remove;

    $target;
}

sub clone_tree_to_slot {
    my ( $self, $slot ) = @_;
    ...
}
*clone_chain_to_slot = \&clone_tree_to_slot;

sub move_tree_to_slot {
    my ( $self, $slot ) = @_;
    ...
}
*move_chain_to_slot = \&move_tree_to_slot;

for my $module_name ( keys %{ $module_data } ) {
    my $module = $module_data->{ $module_name };
    my $meta = meta::package->get( $module->{ class_name } );
    $meta->add_symbol( '@ISA', ['Audio::SunVox::FFI::Module'] );

    $meta->add_symbol( '&get_type', sub{ $module_name } );
    $meta->add_symbol( '&add_to_slot', sub {
            my ( $self, $name ) = @_;
            $self->{ num } = $self->slot->add_module( $module_name, $name );
            $self;
        }
    );

    if ( $module_name eq 'MetaModule' ) {
        $meta->add_symbol( '&load', sub {
            my ( $self, $filename ) = @_;
            # TODO: Figure out if this needs a new slot for each module
            sv_metamodule_load( $self->slot->num, $self->num, $filename );
        } );
    }

    if ( $module_name eq 'Sampler' ) {
        $meta->add_symbol( '&load', sub {
            my ( $self, $filename, $slot ) = @_;
            sampler_load( $self->slot->num, $self->num, $filename, $slot );
        } );
    }

    if ( $module_name eq 'Vorbis player' ) {
        $meta->add_symbol( '&load', sub {
            my ( $self, $filename ) = @_;
            sv_vplayer_load( $self->slot->num, $self->num, $filename );
        } );
    }

    for my $ctl_name ( keys %{ $module->{ ctls } } ) {
        my $ctl = $module->{ ctls }->{ $ctl_name };
        my $method = $ctl->{ method_name };
        for my $scale ( qw/ real hex disp /) {
            $meta->add_symbol(
                "&${method}_$scale",
                _ctl( $ctl, $scale )
            );
        }
        $meta->add_symbol(
            "&$method",
            $meta->get_symbol(
                "&${method}_$default_scale"
            )->reference
        );
    }
}

package Output {
    our @ISA = 'Audio::SunVox::FFI::Module';
    sub num { 0 }
    sub add_to_slot {}
}

=head1 MODULE PARAMETER METHODS

Parameter methods are generated when this module is loaded. See
L<Audio::SunVox::FFI::ClassReference> for a class and method reference,
including valid ranges for each of the scaling options.
Note: Depending on your SunVox library version, this document may not
100% match up with your available modules.

These methods are wrappers for L</ctl_value>.

=cut

1;

