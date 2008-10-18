package Parse::Lotus123::WK4;

=head1 NAME

Parse::Lotus123::WK4 - extract data from Lotus 1-2-3 .wk4 files

=head1 OVERVIEW

This module extracts data from Lotus 1-2-3 .wk4 files.

=head1 SYNOPSIS

Procedural API:
Parse::Lotus123::WK4::parse takes a filehandle and returns a three-dimensional arrayref.
See the source code to wk42csv for more information.

=head1 SOURCES

Description of WK4 format:
L<http://www.mettalogic.uklinux.net/tim/l123/l123r4.html>

Method for decoding IEEE 80-bit floats:
L<http://www.perlmonks.org/?node_id=587419>

=head1 BUGS

This code is experimental, not properly tested and not suitable for production use.

=head1 NO WARRANTY

This code comes with ABSOLUTELY NO WARRANTY of any kind.

=head1 AUTHOR

Written by Franck Latremoliere.
Copyright (c) 2008 Reckon LLP.
L<http://www.reckon.co.uk/staff/franck/>

=head1 LICENCE

This program is free software; you can use, redistribute and/or modify it under the same terms as Perl itself
(Artistic Licence or GNU GPL).

=cut


use warnings;
use strict;

BEGIN {

    $Parse::Lotus123::WK4::VERSION = '0.081';

# test for float endianness using little-endian 33 33 3b f3, which is a float code for 1.4
    
    my $testFloat = unpack( 'f', pack( 'h*', 'f33b3333' ) );
    $Parse::Lotus::WK4::bigEndian = 1
      if ( 2.0 * $testFloat > 2.7 && 2.0 * $testFloat < 2.9 );
    $testFloat = unpack( 'f', pack( 'h*', '33333bf3' ) );
    $Parse::Lotus::WK4::bigEndian = 0
      if ( 2.0 * $testFloat > 2.7 && 2.0 * $testFloat < 2.9 );
    die "Unable to detect endianness of float storage on your machine"
      unless defined $Parse::Lotus::WK4::bigEndian;

}

sub decode_lotus_weirdness {
    my $h = $_[0];
    return $h / 2 if !( $h & 1 );
    my $ld = $h >> 4;
    my $sw = $h & 0x0f;
    return $ld * 5000  if $sw == 0x1;
    return $ld * 500   if $sw == 0x3;
    return $ld / 20    if $sw == 0x5;
    return $ld / 200   if $sw == 0x7;
    return $ld / 2000  if $sw == 0x9;
    return $ld / 20000 if $sw == 0xb;
    return $ld / 16    if $sw == 0xd;
    return $ld / 64    if $sw == 0xf;
}

sub decode_float80 {
    my ( $discard, $mantissa, $hidden, $exponent, $sign ) =
      unpack 'a11 a52 a1 a15 a1', $_[0];
    $exponent = unpack( 'v', pack 'b15', $exponent ) - 16383 + 1023;
    $exponent = 32767, $mantissa = '0' x 52
      if $exponent < 0 || $exponent > 2047;
    $exponent = unpack 'b11', pack 'v', $exponent;
     my $bits64 = $mantissa . $exponent . $sign;
    $bits64 = pack 'a'x8, reverse unpack 'a' x 8, pack 'b64', $bits64
      if $Parse::Lotus::WK4::bigEndian;
    return unpack 'd', $bits64;
}

sub parse($) {
    my $fh       = $_[0] ;
    my $data = [[[]]];
    while ( read( $fh, my $head, 4 ) == 4 ) {
        my ( $code, $len ) = unpack( 'vv', $head );
        my $read = read ($fh, my $byt, $len);
        if ( $read != $len ) {
            # warn "Could not read $len bytes";
            # no need to warn the user:
            # we are probably just at the end of the file and got the structure wrong
        }
        elsif ( $code == 0x16 ) {
            my ( $row, $sheet, $col, $align, $text ) = unpack( 'vCCCA*', $byt );
            $text =~ s/"/'/g;
            $data->[$sheet][$row][$col] = $text;
        }
        elsif ( $code == 0x17 ) {
            my ( $row, $sheet, $col, $b ) = unpack( 'vCCb80', $byt );
            $data->[$sheet][$row][$col] = decode_float80 $b;
        }
        elsif ( $code == 0x19 ) {
            my ( $row, $sheet, $col, $b, $formula ) =
              unpack( 'vCCb80A*', $byt );
            $data->[$sheet][$row][$col] = decode_float80 $b;
        }
        elsif ( $code == 0x18 ) {
            my ( $row, $sheet, $col, $b ) = unpack( 'vCCv', $byt );
            $data->[$sheet][$row][$col] = decode_lotus_weirdness $b;
        }
    }
    $data;
}

1;
