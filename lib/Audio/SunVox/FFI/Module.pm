package Audio::SunVox::FFI::Module;

use strict;
use warnings;

use base 'Exporter';

use meta;
no warnings 'meta::experimental';
my $meta = meta::get_this_package;

use JSON::PP qw/ decode_json /;
use File::Share qw/ dist_file /;
use Carp qw/ carp croak /;
use Audio::SunVox::FFI ':all';
use Audio::SunVox::FFI::Slot;

my $json = dist_file('Audio::SunVox::FFI', 'modules.json');
my $module_data = decode_json do {
    open my $fh, '<', $json or die "Cannot open $json";
    local $/ = undef;
    <$fh>;
};

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
    use DDP; p @_;
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
    bless \%params, $class;
}

sub connect {
    my ( $self, $module, $name ) = @_;
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
    return ( $self, @modules );
}
*connect = \&connect_to;

for my $module_name ( keys %{ $module_data } ) {
    my $module = $module_data->{ $module_name };
    my $meta = meta::package->get( $module->{ class_name } );
    $meta->add_symbol( '@ISA', ['Audio::SunVox::FFI::Module'] );

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

my $meta = meta::package->get( 'Output' );
$meta->add_symbol( '@ISA', ['Audio::SunVox::FFI::Module'] );
$meta->add_symbol('&num', sub { 0 } );

1;
