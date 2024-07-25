package Audio::SunVox::FFI::TrackPool;

# ABSTRACT: Management for real-time event tracks

use strict;
use warnings;

use Carp qw/ carp croak /;
use List::Util qw/ uniq /;

use namespace::clean;

sub new {
    my ( $class ) = @_;
    bless { tracks => [ 0..31 ] }, $class;
}

sub tracks { shift->{ tracks } }

sub hold {
    my ( $self, $count ) = @_;
    $count //= 1;
    push my @tracks, splice @{ $self->tracks }, 0, $count;
    if ( @tracks != $count ) {
        $self->release( @tracks );
        croak "Unable to fulfill track pool request for $count";
    }
    wantarray
        ? @tracks
        : \@tracks;
}

sub release {
    my ( $self, @tracks ) = @_;
    @tracks = @{ $tracks[0] } if ref $tracks[0] && @tracks == 1;
    @{ $self->tracks } =
        uniq
        sort { $a <=> $b }
        grep { $_ >= 0 && $_ < 32 }
        ( @{ $self->tracks }, @tracks );
}

1;

