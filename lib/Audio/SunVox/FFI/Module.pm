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
    my ( $type, $name, $slot ) = @_;
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

sub get_flags {
    my ( $self ) = @_;
    sv_get_module_flags( $self->slot->num, $self->num );
}

# TODO: Wrapper?
sub get_outputs {
    my ( $self ) = @_;
    sv_get_module_outputs( $self->slot->num, $self->num );
}

# TODO: Wrapper?
sub get_inputs {
    my ( $self ) = @_;
    sv_get_module_inputs( $self->slot->num, $self->num );
}

sub get_type {
    my ( $self ) = @_;
    sv_get_module_type( $self->slot->num, $self->num );
}

sub get_name {
    my ( $self ) = @_;
    sv_get_module_name( $self->slot->num, $self->num );
}

sub set_name {
    my ( $self ) = @_;
    sv_set_module_name( $self->slot->num, $self->num );
}

sub get_xy {
    my ( $self ) = @_;
    sv_get_module_xy( $self->slot->num, $self->num );
}

sub set_xy {
    my ( $self ) = @_;
    sv_set_module_xy( $self->slot->num, $self->num );
}

sub get_color {
    my ( $self ) = @_;
    sv_get_module_color( $self->slot->num, $self->num );
}

sub set_color {
    my ( $self ) = @_;
    sv_set_module_color( $self->slot->num, $self->num );
}

sub get_finetune {
    my ( $self ) = @_;
    sv_get_module_finetune( $self->slot->num, $self->num );
}

sub set_finetune {
    my ( $self ) = @_;
    sv_set_module_finetune( $self->slot->num, $self->num );
}

sub set_relnote {
    my ( $self ) = @_;
    sv_set_module_relnote( $self->slot->num, $self->num );
}

sub get_scope { ... }
sub get_scope2 { ... }

sub curve { ... }

sub get_number_of_ctls {
    my ( $self ) = @_;
    sv_get_number_of_module_ctls( $self->slot, $self->num );
}

sub get_ctl_name {
    my ( $self, $ctl ) = @_;
    sv_get_module_ctl_name( $self->slot, $self->num, $ctl );
}

sub get_ctl_value {
    my ( $self, $ctl, $scale ) = @_;
    $scale //= $self->{ default_scale };
    sv_get_module_ctl_value( $self->slot, $self->num, $ctl, $scale );
}

sub set_ctl_value {
    my ( $self, $ctl, $val, $scale ) = @_;
    $scale //= $self->{ default_scale };
    sv_set_module_ctl_value( $self->slot, $self->num, $ctl, $scale );
}

sub get_ctl_min {
    my ( $self, $ctl, $scale ) = @_;
    $scale //= $self->{ default_scale };
    sv_get_module_ctl_min( $self->slot, $self->num, $ctl, $scale );
}

sub get_ctl_max {
    my ( $self, $ctl, $scale ) = @_;
    $scale //= $self->{ default_scale };
    sv_get_module_ctl_max( $self->slot, $self->num, $ctl, $scale );
}

sub get_ctl_offset {
    my ( $self, $ctl ) = @_;
    sv_get_module_ctl_offset( $self->slot, $self->num, $ctl );
}

sub get_ctl_type {
    my ( $self, $ctl ) = @_;
    sv_get_module_ctl_type( $self->slot, $self->num, $ctl );
}

sub get_ctl_group {
    my ( $self, $ctl ) = @_;
    sv_get_module_ctl_group( $self->slot, $self->num, $ctl );
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
}

1;

__END__

=head1 Module and Method Reference

See L<Audio::SunVox::FFI::ClassReference>

=cut
