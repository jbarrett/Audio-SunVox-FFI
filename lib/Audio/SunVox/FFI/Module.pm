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
    my ( $self, $track ) = @_;
    sv_send_event( $self->slot->num, $track, NOTECMD_NOTE_OFF, 0, $self->num + 1 );
}

sub set_pitch {
    my ( $self, $track, $freq, $vel ) = @_;
    my $pitch = 30720 - ( log( $freq / 16.333984375 ) / log( 2 ) ) * 3072;
    sv_send_event( $self->slot->num, $track, NOTECMD_SET_PITCH, $vel, $self->num + 1, 0, $pitch );
}

sub remove {
    my ( $self ) = @_;
    $self->slot->remove_module( $self );
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
        $meta->add_symbol( '&metamodule_load', sub {
            my ( $self, $filename ) = @_;
            # TODO: Figure out if this needs a new slot for each module
            sv_metamodule_load( $self->slot->num, $self->num, $filename );
        } );
    }

    if ( $module_name eq 'Sampler' ) {
        $meta->add_symbol( '&sampler_load', sub {
            my ( $self, $filename, $slot ) = @_;
            sampler_load( $self->slot->num, $self->num, $filename, $slot );
        } );
    }

    if ( $module_name eq 'Vorbis player' ) {
        $meta->add_symbol( '&vplayer_load', sub {
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
