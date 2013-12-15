package String::UnicodeUTF8;

use strict;
use warnings;

use String::Unquotemeta ();
use Module::Want 0.6 ();

$String::UnicodeUTF8::VERSION = '0.21';

sub import {
    return 1 if @_ == 1;    # no-op import()

    my $caller = caller();

    no strict 'refs';       ## no critic
    for ( @_[ 1 .. $#_ ] ) {
        next if $_ eq 'import' || $_ eq '_pre_581_is_utf8_hack';
        *{ $caller . '::' . $_ } = \&{$_} if defined &{$_};
    }
}

# is_utf8() is confusing, it really means “is this a Unicode string”, not “is this a utf-8 bytes string”)
*is_unicode = $] >= 5.008_001 ? \&utf8::is_utf8 : \&_pre_581_is_utf8_hack;    # or just 'use 5.8.1;' and drop this ?

my $pre_573_is_utf8_hack = $] >= 5.007_003 ? undef : {};

sub char_count {
    return CORE::length( get_unicode( $_[0] ) );
}

sub bytes_size {
    return CORE::length( get_utf8( $_[0] ) );
}

sub get_unicode {
    my ($string) = @_;

    if ( !is_unicode($string) ) {
        if ( defined &utf8::decode ) {
            utf8::decode($string);
        }
        else {    # decode() a hacky way:
            $string = pack( "U*", unpack( "C0U*", $string ) );    # 5.6+ at least
        }

        # if decode() did not fully do it (e.g. it only contained ascii characters and utf8::decode() was called)
        if ( !is_unicode($string) ) {

            # force strings without unicode characters to be unicode strings
            if ( defined &utf8::upgrade ) {
                utf8::upgrade($string);
            }
            else {                                                # upgrade() the hacky way: (TODO: how?)
                require Carp;
                Carp::carp("pack() did not result in unicode string and there is no way to emulate utf8::upgrade");
            }
        }
    }

    $pre_573_is_utf8_hack->{$string} = '' if ref $pre_573_is_utf8_hack;
    return $string;
}

sub get_utf8 {
    my ($string) = @_;
    if ( is_unicode($string) ) {
        if ( defined &utf8::encode ) {
            utf8::encode($string);
        }
        else {    # encode() the hacky way:
            $string = pack( "C0U*", unpack( "U*", $string ) );    # 5.6+ at least
        }
    }

    delete $pre_573_is_utf8_hack->{$string} if ref $pre_573_is_utf8_hack;
    return $string;
}

# ? want to serialize these too ?
# my %esc = ( "\n" => '\n', "\t" => '\t', "\r" => '\r', "\\" => '\\\\', "\a" => '\a', "\b" => '\b', "\f" => '\f' );

sub escape_utf8_or_unicode {
    my ( $s, $quotemeta ) = @_;    # undocumented second flag for internal use

    my $is_uni = is_unicode($s);   # otherwise you'll get \xae\x{301} instead of \x{ae}\x{301}

    # ick: patches uber welcome
    if ( $is_uni && $] < 5.008_001 && Module::Want::have_mod('Data::Dumper') ) {
        local $Data::Dumper::Terse = 1;
        $s = Data::Dumper::Dumper($s);
        $s =~ s/\A(["|'])//;
        my $quote = $1;
        $s =~ s/$quote\s*\z//;
        $s =~ s/'/\\'/g unless $quote eq "'";
        return get_utf8($s);
    }

    $s =~ s{([^!#&()*+,\-.\/0123456789:;<=>?ABCDEFGHIJKLMNOPQRSTUVWXYZ\[\]\^_`abcdefghijklmnopqrstuvwxyz{|}~ ])}
        {
            my $chr = "$1";
            my $n   = ord($chr);
            
            # if ( exists $esc{$chr} ) { # more universal way ???
            #     $esc{$chr};
            # }
            # els
            if ( $n < 32 || $n > 126 ) {
                sprintf( ( !$is_uni && $n < 255 ? '\x%02x' : '\x{%04x}' ), $n );
            }
            elsif ($quotemeta) {
                quotemeta($chr);
            }
            else {
                $chr
            }
        }ge;

    return get_utf8($s);
}

sub escape_utf8 {
    my ($string) = @_;
    $string = get_utf8($string);
    return escape_utf8_or_unicode($string);
}

sub escape_unicode {
    my ($string) = @_;
    $string = get_unicode($string);
    return escape_utf8_or_unicode($string);
}

sub unescape_utf8_or_unicode {
    my ( $string, $unquotemeta ) = @_;    # undocumented second flag for internal use
    my $is_uni = $string =~ m/\\x\{[0-9a-fA-f]+\}/ ? 1 : 0;

    $string =~ s/((?:\\x(?:[0-9a-fA-f]{2}|\{[0-9a-fA-f]+\}))+)/eval qq{"$1"}/eg;    ## no critic
    $string = String::Unquotemeta::unquotemeta($string) if $unquotemeta;
    return get_unicode($string) if $is_uni;
    return get_utf8($string);
}

sub unescape_utf8 {
    my ($string) = @_;
    $string = unescape_utf8_or_unicode($string);
    return get_utf8($string);
}

sub unescape_unicode {
    my ($string) = @_;
    $string = unescape_utf8_or_unicode($string);
    return get_unicode($string);
}

sub quotemeta_bytes {    # I ♥ perl\'s coolness
    my $utf8_quoted = quotemeta_utf8( $_[0] );
    return unescape_utf8_or_unicode($utf8_quoted);
}

sub quotemeta_utf8 {     # I \xe2\x99\xa5 perl\'s coolness
    my ($string) = @_;
    $string = get_utf8($string);
    return escape_utf8_or_unicode( $string, 1 );
}

sub quotemeta_unicode {    # I \x{2665} perl\'s coolness
    my ($string) = @_;
    $string = get_unicode($string);
    return escape_utf8_or_unicode( $string, 1 );
}

sub unquotemeta_bytes {
    goto &unquotemeta_utf8;
}

sub unquotemeta_utf8 {
    my ($escaped_string) = @_;
    $escaped_string = unescape_utf8_or_unicode( $escaped_string, 1 );
    return get_utf8($escaped_string);
}

sub unquotemeta_unicode {
    my ($escaped_string) = @_;
    $escaped_string = unescape_utf8_or_unicode( $escaped_string, 1 );
    return get_unicode($escaped_string);
}

sub _pre_581_is_utf8_hack {
    my ($string) = @_;

    # strings with unicode characters that are unicode strings
    require bytes;
    return 1 if bytes::length($string) != CORE::length($string);

    # strings without unicode characters that are unicode strings
    if ( Module::Want::have_mod('Encode') ) {
        return 1 if Encode::is_utf8($string);
    }
    else {

        # So we have a string without unicode characters and no utf8::is_utf8() or Encode::is_utf8(), time to get hacky!
        if ( Module::Want::have_mod('B::Flags') && defined &B::svref_2object ) {    # B::Flags brings in B *but* B::svref_2object can be compiled away in some specific circumstances
            return 1 if B::svref_2object( \$string )->flagspv() =~ m/UTF.?8/i;      # works on 5.6!
        }
        else {

            # oi, still nothing is available at this point so time to get reeeeeaaaallly hacky! (patches very very welcome, this is a terrible last ditch effort)

            # not fool proof (same text–different-string/variable or [down|up]grade() outside of get_[utf8|unicode])
            return 1 if exists $pre_573_is_utf8_hack->{$string};
        }
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

String::UnicodeUTF8 - non-collation related unicode/utf-8 bytes string-type-agnostic utils that work as far back as perl 5.6

=head1 VERSION

This document describes String::UnicodeUTF8 version 0.21

=head1 SYNOPSIS

    use String::UnicodeUTF8 qw(char_count bytes_size is_unicode);
    
    say '$string type is: ' . is_unicode($string) ? 'Unicode' : 'bytes';
    
    say '$string has this many characters: ' . char_count($string);
    
    say '$string takes up this many bytes: ' . bytes_size($string);

=head1 DESCRIPTION

Unicode is awesome. utf-8 is also awesome. They are related but different. That difference and all the little twiggles in between make it appear to be too hard but its really not, honest!

The unicode problem is a solved one. The easiest way to manage day to day is have a couple of simple items in mind:

=over 4

=item “Unicode” is a set of characters.

Example: ♥ is Unicode character number 2665 (hexidecimal numbers those be)

=item “utf-8” is an encoding of Unicode characters

Example: ♥ (i.e. Unicode character number 2665) is made of of 3 octets, or “characters” semantically, numbered: e2, 99, and a5 (hexidecimal numbers those be)

=item You (almost) always want to input/output bytes in utf-8

By this I mean all of the files, data base connections/schema, HTTP request/response, etc etc. You may very well need to encode to/from utf-8 when dealing with 3rdparty/external stuff you have little control over.

I say almost because it is possible to use any number of encodings and I suppose you might encounter a situation when you have no other choice. But if you have choice and an IQ in the double digits just do utf-8, its not that hard to do and you’ll expontially* make your life and others' easier.

If you do have a situation (and its not an ignorant boss/client forcing his moron–induced–FUD on you) please drop me a line w/ details. Who knows I may recant!

* no actual math has been harmed in this statement, patches welcome!

=item perl basically has 2 types if strings: “Unicode” and “bytes”

The former has the UTF-8 SV flag set which tells perl to treat a Unicode character as one item (i.e. as apposed to 3 in our ♥ example).

The latter are just bytes that could be anything (hopefully explicitly utf-8 in our case!).

=back

=head2 What this module is not meant for

=over 4

=item Collation related stuff.

Use something like L<Unicode::Collate> for that.

=item Unicode problem stuff.

See L<perlunicode> for more info.

=item Anything not explicitly stated in the POD.

=back 

=head2 What this module is meant for

=over 4

=item Consistent terminology.

The term “utf-8” and “Unicode” (akin to “encoding” and “charset”) are typically used ambiguously and perl docs are not immune.

It could mean either a Unicode string or a bytes string depending on the “thing” in question. ick, just ick. That is where this module comes in. 

It defines those concepts strictly as “Unicode string” and “utf-8 bytes string” (the latter is shortened by removing the first or second word because they are essentially synonymous conceptually).

Based on that it gives functions that operate consistently regardless of the type (or regardful if you intend one or the other, your needs; your call).

=item Availablity

The functions necessary to do all of this are not available on older perls.

e.g. utf8::is_utf8 is not available before 5.8.1. L<Encode> is not avialble before 5.7.3.

=item The steps to do the things this does are better wrapped up for sanity/reusability.

Do I need to encode, decode, upgrade, downgrade.

Do I use the return value or does it modify the SV in place?

=back

=head2 Glossary

This glossary holds true when doing the stuff this module does only with this module. If you fiddle with the guts then its more likely you can end up in a wonky pseudo state.

=head3 UTF-8 Bytes String

A string of bytes whose Unicode characters are made up of utf-8 byte sequences (e.g. \xe2\x99\xa5 in our heart example). Each Unicode character is handled internally by perl as the bytes that make it up (and not as a single Unicode character).

=head3 Unicode String

A L<UTF-8 Bytes String> that additionally has it’s UTF-8 flag set so that perl treats utf-8 byte sequences as the individual Unicode character it makes up (e.g. \x{2665} in our heart example).

=head2 A word on unicode and utf-8 representation in source code

Another point of confusion can be how unicode and utf-8 are represented in source code and the default or pragma set treatment of utf-8.

The characer itself:

    perl -e 'print utf8::is_utf8("I ♥ perl") . "\n";'          # could be a L<UTF-8 Bytes String> or a L<Unicode String> depending on perl’s “mode”.
    perl -e 'use utf8;print utf8::is_utf8("I ♥ perl") . "\n";' # a L<Unicode String> because of perl’s “mode”.
    perl -e 'no utf8;print utf8::is_utf8("I ♥ perl") . "\n";'  # a L<UTF-8 Bytes String>because of perl’s “mode”.

\x octet notation:

    perl -e 'print utf8::is_utf8("I \xe2\x99\xa5 perl") . "\n";'          # a L<UTF-8 Bytes String> regardless of perl’s “mode”.
    perl -e 'use utf8;print utf8::is_utf8("I \xe2\x99\xa5 perl") . "\n";' # a L<UTF-8 Bytes String> regardless of perl’s “mode”.
    perl -e 'no utf8;print utf8::is_utf8("I \xe2\x99\xa5 perl") . "\n";'  # a L<UTF-8 Bytes String> regardless of perl’s “mode”.

\x unicode notation:

    perl -e 'print utf8::is_utf8("I \x{2665} perl") . "\n";'          # a L<Unicode String> regardless of perl’s “mode”.
    perl -e 'use utf8;print utf8::is_utf8("I \x{2665} perl") . "\n";' # a L<Unicode String> regardless of perl’s “mode”.
    perl -e 'no utf8;print utf8::is_utf8("I \x{2665} perl") . "\n";'  # a L<Unicode String> regardless of perl’s “mode”.

bracketed \x octet: 

This one I don’t like. It is ambiguous (it is octets but it looks like unicode). I almost always only see it when data is in the process of being corrupted.

    perl -e 'print utf8::is_utf8("I \x{e2}\x{99}\x{a5} perl") . "\n";'

Good rule of thumb is to be explicit with your intent: use brackets form with 4+ digits (zero padded if necessary) and non-bracket form with 2 digits.

=head2 Tips on troubleshooting Unicode/utf-8 problems

I’ll maintain some more detailed Unicode resources L<at my Unicode page|http://drmuey.com/?do=page&id=57> but for this doc there are 3 things that will help you:

=over 4

=item 1 checks the bytes

Don’t look so much at seemingly corrupt display, examine the bytes at the source. Once you verify they are legit you can move on to finding out what it is that is mishandling them along the route.

For example, you might do a SELECT on a column and also include the column in HEX and the character and bytes lengths of the column in the query. If the bytes are correct but the character length is wrong then that is a great hint as to where to look next.

For perl, make sure you do so on bytes strings:

    multivac:~ dmuey$ perl -le 'no utf8;print unpack("H*", "I ♥ Perl");'
    4920e299a5205065726c
    multivac:~ dmuey$ perl -le 'use utf8;print unpack("H*", "I ♥ Perl");'
    492065205065726c
    multivac:~ dmuey$ perl -le 'no utf8;print pack("H*", "4920e299a5205065726c");'
    I ♥ Perl
    multivac:~ dmuey$ perl -le 'use utf8;print pack("H*", "4920e299a5205065726c");'
    I ♥ Perl
    multivac:~ dmuey$ perl -le 'use utf8;print pack("H*", "492065205065726c");'
    I e Perl
    multivac:~ dmuey$ perl -le 'no utf8;print pack("H*", "492065205065726c");'
    I e Perl
    multivac:~ dmuey$

Even better, use a tool that does what you mean regardless of the type of string:

e.g. Devel::Kit does what you mean regardless of the type (via this module as it happens ;p):

    [dmuey@multivac ~]$ perl -MDevel::Kit -e 'no utf8;xe("I ♥ Perl",1);'
    debug(): Hex: 	[
          'I : 49',
          '  : 20',
          '♥ : e299a5',
          '  : 20',
          'P : 50',
          'e : 65',
          'r : 72',
          'l : 6c'
        ]
    [dmuey@multivac ~]$ perl -MDevel::Kit -e 'use utf8;xe("I ♥ Perl",1);'
    debug(): Hex: 	[
          'I : 49',
          '  : 20',
          '♥ : e299a5',
          '  : 20',
          'P : 50',
          'e : 65',
          'r : 72',
          'l : 6c'
        ]
    [dmuey@multivac ~]$

=item 2 use the simplest scenario

If you can rule out as many factors as possible (HTTP request/response, database settings, perl -E enabling optional features that could affect Unicode/utf8-bytes,  etc) it will help you hone in on where your good bytes went bad.

=item 3 use the simplest string

I tend to use 'I ♥ Unicode' so that there is one multi-byte Unicode character to examine. Also, it is a visible charcater that most fonts support, which helps.

=back

=head1 INTERFACE

All of these functions are exportable.

=head2 is_unicode()

Like utf8::is_utf8() but is less ambiguously named* and works on perls before utf8::is_utf8() and Encode::is_utf8() as far back as, at least, 5.6.2.

There is one rare caveat: If you have an old perl, you have a string that contains no Unicode characters, you are in compiled perl w/ B optomized away, and you've upgraded a string outside of the functions in this module (or use the same text in different scalars). You *may* get erroneous results.

* is_utf8() does not mean “are these bytes in utf-8 encoding (as apposed to, say, utf-16, latin1, etc etc)”, it means “are these bytes in utf-8 encoding and is the UTF-8 flag set on this string” (i.e. is this a Uncode string):

Don’t take my word for it, try it your self:

    perl -e 'print utf8::is_utf8("I \xe2\x99\xa5 perl") . "\n";print utf8::is_utf8("I \x{2665} perl") . "\n";' # this is the same on 5.6.2 as 5.16.0

=head2 char_count()

Get the number of characters, conceptually, of the given string regardless of the argument’s type.

e.g. "I \x{2665} perl" and "I \xe2\x99\xa5 perl" both have 8 characters. The latter just happens to be encoded in utf-8 which uses a sequence of three smaller “characters” to represent the one conceptual unicode character “♥”.

=head2 bytes_size()

Get the number of bytes of the given string regardless of the argument’s type.

=head2 get_unicode()

Get a L</Unicode String> version of the given string regardless of the argument’s type.

=head2 get_utf8()

Get a L</UTF-8 Bytes String> version of the given string regardless of the argument’s type.

=head2 escape_utf8_or_unicode()

Serialize unicode characters as slash-x notation:: \x{2665} style if the argument was a L</Unicode String>. \xe2\x99\xa5 style if the argument was a L</UTF-8 Bytes String>.

Returns a L</UTF-8 Bytes String> since it should contain no unicode characters at this point.

=head3 escape_utf8()

Like L<escape_utf8_or_unicode()> but force it to be in L</UTF-8 Bytes String> style \xe2\x99\xa5 notation.

=head3 escape_unicode()

Like L<escape_utf8_or_unicode()> but force it to be in L</Unicode String> style \x{2665} notation.

=head2 unescape_utf8_or_unicode()

Turn slash-x notation back into the character. 

If there was a L</Unicode String> \x{2665} style escape it returns a L</Unicode String>.

Otherwise it returns a L</UTF-8 Bytes String>.

=head3 unescape_utf8()

Like L<unescape_utf8_or_unicode()> but force it to return a L</UTF-8 Bytes String> regardless of slash-x type.

=head3 unescape_unicode()

Like L<unescape_utf8_or_unicode()> but force it to return a L</Unicode String> regardless of slash-x type.

=head2 quotemeta_bytes()

Unicode aware version of L<quotemeta()> that returns a L</UTF-8 Bytes String> that has unicode characters represented as their characters.

=head2 quotemeta_utf8()

Unicode aware version of L<quotemeta()> that returns a L</UTF-8 Bytes String> that has unicode characters represented in \xe2\x99\xa5 notation.

=head2 quotemeta_unicode()

Unicode aware version of L<quotemeta()> that returns a L</Unicode String> that has unicode characters represented in \x{2665} notation.

=head2 unquotemeta_bytes()

Alias of L<unquotemeta_utf8()>. Exists to semantically correspond to L<quotemeta_bytes()>.

=head2 unquotemeta_utf8()

Unicode aware version of L<String::Unquotemeta/unquotemeta()> that returns a L</UTF-8 Bytes String>.

=head2 unquotemeta_unicode()

Unicode aware version of L<String::Unquotemeta/unquotemeta()> that returns a L</Unicode String>.

=head1 DIAGNOSTICS

Throws no warnings or errors of its own, except:

=over

=item C<< pack() did not result in unicode string and there is no way to emulate utf8::upgrade >>

This essentially should never happen and mainly exists for completeness. It is only possible on pre 5.8.1 perls. If you are ever able to get L<get_unicode()> to carp() this please send the details!

=back

=head1 CONFIGURATION AND ENVIRONMENT

String::UnicodeUTF8 requires no configuration files or environment variables.

=head1 DEPENDENCIES

L<String::Unquotemeta>

is_unicode(), when given a string with no unicode characters, lazy loads L<Encode> for perl versions from 5.7.3 to 5.8.1, L<B::Flags> for < 5.7.3

L<Module::Want> is used for the lazy loading since there are advantages over straight eval.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-string-unicodeutf8@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 TODO

\N notation escaping/unescaping: Seems like YAGNI but if there is enough demand we can add it (lazy/separate since it’d be heavy).

=head1 AUTHOR

Daniel Muey  C<< <http://drmuey.com/cpan_contact.pl> >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2012, Daniel Muey C<< <http://drmuey.com/cpan_contact.pl> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
