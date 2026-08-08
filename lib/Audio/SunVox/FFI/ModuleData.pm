use strict;
use warnings;
package Audio::SunVox::FFI::ModuleData;

# ABSTRACT: Module data and parameters - used to build this distribution.

use Carp qw/ croak carp /;
use FindBin;
use Audio::SunVox::FFI ':all';

our $VERSION = '0.00';

my @modules = map { s/^\s*//; $_ } split /[\n\r]+\s*/, <<'MODULES';
    Analog generator
    DrumSynth
    FM
    FMX
    Generator
    Input
    Kicker
    Vorbis player
    Sampler
    SpectraVoice
    Amplifier
    Compressor
    DC Blocker
    Delay
    Distortion
    Echo
    EQ
    FFT
    Filter
    Filter Pro
    Flanger
    LFO
    Loop
    Modulator
    Pitch shifter
    Reverb
    Vocal filter
    Vibrato
    WaveShaper
    ADSR
    Ctl2Note
    Feedback
    Glide
    GPIO
    MetaModule
    MultiCtl
    MultiSynth
    Pitch2Ctl
    Pitch Detector
    Sound2Ctl
    Velocity2Ctl
MODULES

sub all_module_types { @modules }

sub _class_name {
    my ( $name ) = @_;
    return $name if uc $name eq $name;
    return $name if $name !~ /\s/;
    return 'DCBlocker' if $name eq 'DC Blocker';
    join '', map { ucfirst } split ' ', $name;
}

sub _method_name {
    my ( $name ) = @_;
    $name =~ s/\s+\(.*\)$// if $name !~ /\(lite/;
    $name =~ s/[()]//g;
    $name =~ s/-/ /g;
    $name =~ s/[\s.]+/_/g;
    lc $name;
}

sub _query_module {
    my ( $module ) = @_;
    sv_lock_slot( 0 );
    my $modnum = sv_new_module( 0, $module, $module );
    sv_unlock_slot( 0 );
    my $ctl = 0;
    my $ctls;
    while ( my $ctl_name = sv_get_module_ctl_name(0, $modnum, $ctl ) ) {
        $ctls->{ $ctl_name } = {
            ctl_num     => $ctl,
            method_name => _method_name( $ctl_name ),
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
        class_name => _class_name( $module ),
        ctls => $ctls,
    }
}

my $_module_data;
sub _module_data {
    return $_module_data if $_module_data;
    my ( $disclaimer ) = @_;
    if ( $disclaimer ne "I understand that this will break my patch" ) {
        carp "Probably better if you don't run this";
        return -1;
    }
    sv_init( '', 48_000, 2, SV_INIT_FLAG_OFFLINE | SV_INIT_FLAG_NO_DEBUG_OUTPUT );
    sv_open_slot( 0 );
    $_module_data = { map { $_ => _query_module( $_ ) } @modules };
    sv_close_slot( 0 );
    sv_deinit;
}


sub _module_doc {
    my ( $name, $module ) = @_;
    my $doc = "=head2 C<$module->{ class_name }> - $name\n\n";
    for my $ctl_name ( sort { $module->{ ctls }->{ $a }->{ ctl_num } <=> $module->{ ctls }->{ $b }->{ ctl_num } } keys %{ $module->{ ctls } } ) {
        my $ctl = $module->{ ctls }->{ $ctl_name };
        my $meth = $ctl->{ method_name };
        $doc.= "=head3 C<$meth();> - $ctl_name\n\n=over 4\n\n";
        for my $scale (qw/ real hex disp /) {
            my $max = $ctl->{ "max_$scale" };
            my $min = $ctl->{ "min_$scale" };
            $doc.= $scale eq 'hex'
                ? sprintf( "=item *\n\nC<${meth}_$scale( 0x%X - 0x%X );>\n\n", $min, $max )
                : "=item *\n\nC<${meth}_$scale( $min - $max );>\n\n";
        }
        $doc .= "=back\n\n";
    }
    $doc;
}

sub _generate_appendix {
    my $doc = "# PODNAME: Audio::SunVox::FFI::ClassReference\n\n";
    $doc .= "# ABSTRACT: Class and method reference for Audio::SunVox::FFI::Module\n\n";
    $doc .= "=pod\n\n";
    $doc .= "=head1 Generated Classes and Methods\n\n";

    for my $module_name ( all_module_types ) {
        my $module = $_module_data->{ $module_name };
        $doc .= _module_doc( $module_name, $module );
    }

    print $doc;
}

1;
