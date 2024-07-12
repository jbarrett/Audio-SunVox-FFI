#!/usr/bin/env perl

use JSON::PP qw/ encode_json /;
use File::Share qw/ dist_file /;
use FindBin;
use lib "$FindBin::Bin/../lib/";
use Audio::SunVox::FFI ':all';
my $json = dist_file('Audio-SunVox-FFI', 'modules.json');

my @modules = sv_get_all_module_types;

sub class_name {
    my ( $name ) = @_;
    return $name if uc $name eq $name;
    return $name if $name !~ /\s/;
    return 'DCBlocker' if $name eq 'DC Blocker';
    join '', map { ucfirst } split ' ', $name;
}

sub method_name {
    my ( $name ) = @_;
    $name =~ s/\s+\(.*\)$// if $name !~ /\(lite/;
    $name =~ s/[()]//g;
    $name =~ s/-/ /g;
    $name =~ s/[\s.]+/_/g;
    lc $name;
}

sub query {
    my ( $module ) = @_;
    sv_lock_slot( 0 );
    my $modnum = sv_new_module( 0, $module, $module );
    sv_unlock_slot( 0 );
    my $ctl = 0;
    my $ctls;
    while ( my $ctl_name = sv_get_module_ctl_name(0, $modnum, $ctl ) ) {
        $ctls->{ $ctl_name } = {
            ctl_num     => $ctl,
            method_name => method_name( $ctl_name ),
            min_real    => sv_get_module_ctl_min( 0, $modnum, $ctl, 0 ),
            max_real    => sv_get_module_ctl_max( 0, $modnum, $ctl, 0 ),
            min_hex     => sv_get_module_ctl_min( 0, $modnum, $ctl, 1 ),
            max_hex     => sv_get_module_ctl_max( 0, $modnum, $ctl, 1 ),
            min_disp    => sv_get_module_ctl_min( 0, $modnum, $ctl, 2 ),
            max_disp    => sv_get_module_ctl_max( 0, $modnum, $ctl, 2 ),
        };
        ++$ctl;
    }
    +{
        class_name => class_name( $module ),
        ctls => $ctls,
    }
}

sv_init('', 48_000, 2, SV_INIT_FLAG_OFFLINE);
sv_open_slot( 0 );

my $module_data = {
    map { $_ => query( $_ ) } @modules
};

open my $fh, '>', $json or die "Cannot open $json";
print $fh JSON::PP->new->canonical->pretty->encode( $module_data );
