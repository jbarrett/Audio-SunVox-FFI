package Audio::SunVox::FFI::Module;

# ABSTRACT: Objects for SunVox Modules

use strict;
use warnings;

use base 'Exporter';

use meta;
no warnings 'meta::experimental';
my $meta = meta::get_this_package;

use Carp qw/ carp croak /;
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

use namespace::clean;

my $get_dispatch = {
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

my $set_dispatch = {
    name     => \&sv_set_module_name,
    xy       => \&sv_set_module_xy,
    color    => \&sv_set_module_color,
    finetune => \&sv_set_module_finetune,
    relnote  => \&sv_set_module_relnote,
};

for my $method ( keys %{ $get_dispatch } ) {
    $meta->add_symbol( "&$method", sub {
        my ( $self, @params ) = @_;
        return $get_dispatch->{ $method }->( $self->slot->num, $self->num ) unless @params;
        if ( ! ( my $prop = $set_dispatch->{ $method } ) ) {
            carp "Read-only property: $prop";
            return -1;
        }
        $set_dispatch->{ $method }->( $self->slot->num, $self->num, @params );
    } );
}

sub ctl_min {
    my ( $self, $ctl, $scale ) = @_;
    $scale //= $self->default_scale;
    sv_get_module_ctl_min( $self->slot->num, $self->num, $ctl, $scale );
}

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
        return sv_set_module_ctl_value( $self->slot->num, $self->num, $ctl, $val, $self->scale( $scale ) )
            if defined $val;
        sv_get_module_ctl_value( $self->slot->num, $self->num, $ctl, $self->scale( $scale ) );
    } );
}

sub _ctl {
    my ( $ctl, $scale ) = @_;
    my ( $min, $max, $method_name ) = @{ $ctl }{ "min_$scale", "max_$scale", 'method_name' };
    sub {
        my ( $self, $value ) = @_;

        return sv_get_module_ctl_value( $self->slot->num, $self->num, $ctl->{ ctl_num }, $self->scale( $scale ) )
            unless defined $value;

        goto nobounds if $self->skip_bounds_checking;
        if ( $value < $min ) {
            carp "Value $value below minimum of $min for $ctl->{ method_name } - setting to $min";
            $value = $min;
        }
        elsif ( $value > $max ) {
            carp "Value $value below maximum of $max for $ctl->{ method_name } - setting to $max";
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
    my $self = bless \%params, $class;
    $self->add_to_slot( $params{ name } ) unless $self->{ in_slot };
    $self;
}

sub skip_bounds_checking {
    my ( $self, $val ) = @_;
    $self->{ skip_bounds_checking } = $val if defined $val;
    $self->{ skip_bounds_checking };
}

sub scale { $scales->{ $_[1] } }

sub num { shift->{ num } }

sub slot { shift->{ slot } }

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

sub note_on {
    my ( $self, $track, $note, $vel ) = @_;
    sv_send_event( $self->slot->num, $track, $note, $vel, $self->num + 1 );
}

sub note_off {
    my ( $self, $track, $note ) = @_;
    sv_send_event( $self->slot->num, $track, NOTECMD_NOTE_OFF, $note, $self->num + 1 );
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

sub scope {
    my ( $self, $channel, $samples ) = @_;
    sv_get_module_scope2( $self->slot->num, $self->num, $channel, $samples );
}

# Curve -> length
my $curve_map = {
    MultiSynth => [ 128, 257, 128 ], # note/velocity, velocity/velocity, note/pitch
    WaveShaper => [ 256 ],           # waveshaper curve
    MultiCtl   => [ 257 ],           # multictl curve
    Generator  => [ 32 ]             # drawn waveform
};

sub curve {
    my ( $self, $curve_num, $data, $length ) = @_;
    $length //= $curve_map->{ ref $self }->[ $curve_num ];
    sv_module_curve( $self->slot->num, $self->num, $curve_num, $data, $length );
}

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
    use base 'Audio::SunVox::FFI::Module';
    sub num { 0 }
    sub add_to_slot {}
}

1;

__END__

=head1 Module and Method Reference

See L<Audio::SunVox::FFI::ClassReference>

=cut
