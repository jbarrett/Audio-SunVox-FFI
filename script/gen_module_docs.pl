#!/usr/bin/env perl

use JSON::PP qw/ decode_json /;
use File::Share qw/ dist_file /;
use FindBin;
use lib "$FindBin::Bin/../lib/";
use Audio::SunVox::FFI qw/ sv_get_all_module_types /;

my $json = dist_file('Audio::SunVox::FFI', 'modules.json');
my $module_data = decode_json do {
    open my $fh, '<', $json or die "Cannot open $json";
    local $/ = undef;
    <$fh>;
};

use Audio::SunVox::FFI::Module;
my $fn = $INC{'Audio/SunVox/FFI/Module.pm'};

sub doc {
    my ( $name, $module ) = @_;
    my $doc = "=head2 C<$module->{ class_name }> - $name\n\n=over 4\n\n";
    for my $ctl_name ( sort { $module->{ ctls }->{ $a }->{ ctl_num } <=> $module->{ ctls }->{ $b }->{ ctl_num } } keys %{ $module->{ ctls } } ) {
        my $ctl = $module->{ ctls }->{ $ctl_name };
        my $meth = $ctl->{ method_name };
        $doc.= "=item *\n\nC<$meth();> - $ctl_name\n\n=over 4\n\n";
        for my $scale (qw/ real hex disp /) {
            my $max = $ctl->{ "max_$scale" };
            my $min = $ctl->{ "min_$scale" };
            $doc.= $scale eq 'hex'
                ? sprintf( "=item *\n\nC<${meth}_$scale( 0x%X - 0x%X );>\n\n", $min, $max )
                : "=item *\n\nC<${meth}_$scale( $min - $max );>\n\n";
        }
        $doc .= "=back\n\n";
    }
    $doc .= "=back\n\n";
}

my $doc;
for my $module_name ( sv_get_all_module_types ) {
    my $module = $module_data->{ $module_name };
    $doc .= doc( $module_name, $module );
}

my $src = do {
    open my $fh, '<', $fn or die "Cannot open $fn";
    local $/ = undef;
    <$fh>;
};

$src =~ s/MODULE_REFS_HERE/$doc/;
open my $fh, '>', $fn;
print $fh $src;

