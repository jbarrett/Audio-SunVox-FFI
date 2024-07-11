package Audio::SunVox::FFI::Slot;

use strict;
use warnings;

use Carp qw/ carp croak /;
use Audio::SunVox::FFI ':all';

my $slot = -1;
my $first;
my $last;
my $initialised = 0;

sub new {
    my ( $class, %params ) = @_;
    $slot++;
    croak "No more slots available" if $slot > 15;
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

sub get_last {
    $last //= shift->new;
}

1;
