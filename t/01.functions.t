use Test::More tests => 40 + 14 + 12 + ( 7 * 28 );

use String::UnicodeUTF8;

diag("Testing String::UnicodeUTF8 $String::UnicodeUTF8::VERSION");

for my $n (qw(import _pre_581_is_utf8_hack function_that_does_not_exist)) {
    ok( !eval "defined \&$n", "pre import sanity check for $n()" );
    String::UnicodeUTF8->import($n);
    ok( !eval "defined \&$n", "$n is not import()ed" );
}
for my $f (qw(is_unicode char_count bytes_size get_unicode get_utf8 quotemeta_bytes quotemeta_utf8 quotemeta_unicode unquotemeta_bytes unquotemeta_utf8 unquotemeta_unicode escape_utf8_or_unicode escape_utf8 escape_unicode unescape_utf8_or_unicode unescape_utf8 unescape_unicode)) {
    ok( !eval "defined \&$f", "pre import sanity check for $f()" );
    String::UnicodeUTF8->import($f);
    ok( eval "defined \&$f", "$f is import()ed ok" );
}

#### test vars ##

my $bytes_ascii      = 'I love perl';
my $b_grapheme_ascii = "I love \x70erl";
my $unicode_ascii    = 'I love perl';

# This won't work on 5.6:
#   utf8::decode($unicode_ascii);
#   utf8::upgrade($unicode_ascii);
# so do it the hacky way:
$unicode_ascii = pack( "U*", unpack( "C0U*", $unicode_ascii ) );    # 5.6+ at least

my $bytes_unichar;
{
    no utf8;
    $bytes_unichar = "I ♥ perl";
}
my $unicode_unichar;
{
    use utf8;
    $unicode_unichar = "I ♥ perl";
}
my $b_grapheme_unichar = "I \xe2\x99\xa5 perl";
my $u_grapheme_unichar = "I \x{2665} perl";

#### functions ##

SKIP: {
    skip 'is_unicode() compat tests skipped on systems without utf8::is_utf8()', 14 unless defined &utf8::is_utf8;

    # is_unicode
    is( !!is_unicode("I love perl"),    !!utf8::is_utf8("I love perl"),    "perl v$]: is_unicode() boolean RV matches utf8::is_utf8() w/ bytes non-grapheme string - all ascii" );
    is( !!is_unicode("I love \x70erl"), !!utf8::is_utf8("I love \x70erl"), "perl v$]: is_unicode() boolean RV matches utf8::is_utf8() w/ bytes grapheme string- all ascii" );

    is( !!is_unicode($unicode_ascii), !!utf8::is_utf8($unicode_ascii), "perl v$]: is_unicode() boolean RV matches utf8::is_utf8() w/ unicode string- all ascii" );

    {
        no utf8;
        is( !!is_unicode("I ♥ perl"), !!utf8::is_utf8("I ♥ perl"), "perl v$]: is_unicode() boolean RV matches utf8::is_utf8() w/ bytes non-grapheme string - has unicode" );
    }
    is( !!is_unicode("I \xe2\x99\xa5 perl"), !!utf8::is_utf8("I \xe2\x99\xa5 perl"), "perl v$]: is_unicode() boolean RV matches utf8::is_utf8() w/ bytes grapheme string - has unicode" );
    {
        use utf8;
        is( !!is_unicode("I ♥ perl"), !!utf8::is_utf8("I ♥ perl"), "perl v$]: is_unicode() boolean RV matches utf8::is_utf8() w/ unicode string - has unicode" );
    }
    is( !!is_unicode("I \x{2665} perl"), !!utf8::is_utf8("I \x{2665} perl"), "perl v$]: is_unicode() boolean RV matches utf8::is_utf8() w/ unicode graphem string string - has unicode" );

    # _pre_581_is_utf8_hack
    is( !!String::UnicodeUTF8::_pre_581_is_utf8_hack("I love perl"),    !!utf8::is_utf8("I love perl"),    "perl v$]: _pre_581_is_utf8_hack() boolean RV matches utf8::is_utf8() w/ bytes non-grapheme string - all ascii" );
    is( !!String::UnicodeUTF8::_pre_581_is_utf8_hack("I love \x70erl"), !!utf8::is_utf8("I love \x70erl"), "perl v$]: _pre_581_is_utf8_hack() boolean RV matches utf8::is_utf8() w/ bytes grapheme string- all ascii" );
    is( !!String::UnicodeUTF8::_pre_581_is_utf8_hack($unicode_ascii),   !!utf8::is_utf8($unicode_ascii),   "perl v$]: _pre_581_is_utf8_hack() boolean RV matches utf8::is_utf8() w/ unicode string- all ascii" );

    {
        no utf8;
        is( !!String::UnicodeUTF8::_pre_581_is_utf8_hack("I ♥ perl"), !!utf8::is_utf8("I ♥ perl"), "perl v$]: _pre_581_is_utf8_hack() boolean RV matches utf8::is_utf8() w/ bytes non-grapheme string - has unicode" );
    }
    is( !!String::UnicodeUTF8::_pre_581_is_utf8_hack("I \xe2\x99\xa5 perl"), !!utf8::is_utf8("I \xe2\x99\xa5 perl"), "perl v$]: _pre_581_is_utf8_hack() boolean RV matches utf8::is_utf8() w/ bytes grapheme string - has unicode" );
    {
        use utf8;
        is( !!String::UnicodeUTF8::_pre_581_is_utf8_hack("I ♥ perl"), !!utf8::is_utf8("I ♥ perl"), "perl v$]: _pre_581_is_utf8_hack() boolean RV matches utf8::is_utf8() w/ unicode string - has unicode" );
    }
    is( !!String::UnicodeUTF8::_pre_581_is_utf8_hack("I \x{2665} perl"), !!utf8::is_utf8("I \x{2665} perl"), "perl v$]: _pre_581_is_utf8_hack() boolean RV matches utf8::is_utf8() w/ unicode graphem string string - has unicode" );
}

my %uni_set = (
    'quotemeta_bytes'   => q{I ♥ perl\\'s coolness},
    'quotemeta_utf8'    => q{I \xe2\x99\xa5 perl\\'s coolness},
    'quotemeta_unicode' => q{I \x{2665} perl\\'s coolness},

    'unquotemeta_bytes'   => "I \xe2\x99\xa5 perl's coolness",    # always bytes, regardless of utf8 pragma
    'unquotemeta_utf8'    => "I \xe2\x99\xa5 perl's coolness",    # always bytes, regardless of utf8 pragma
    'unquotemeta_unicode' => "I \x{2665} perl's coolness",        # always unicode, regardless of utf8 pragma
);
my %ascii_set = (
    'quotemeta_bytes'   => q{I love perl\\'s coolness},
    'quotemeta_utf8'    => q{I love perl\\'s coolness},
    'quotemeta_unicode' => q{I love perl\\'s coolness},

    'unquotemeta_bytes'   => qq{I love perl's coolness},          # always bytes, regardless of utf8 pragma
    'unquotemeta_utf8'    => qq{I love perl's coolness},          # always bytes, regardless of utf8 pragma
    'unquotemeta_unicode' => qq{I love perl's coolness},          # always unicode, regardless of utf8 pragma
);

my %test_strings = (
    'bytes_ascii' => {
        'char_count' => 11,
        'bytes_size' => 11,
        %ascii_set,
    },
    'b_grapheme_ascii' => {
        'char_count' => 11,
        'bytes_size' => 11,
        %ascii_set,
    },
    'unicode_ascii' => {
        'char_count' => 11,
        'bytes_size' => 11,
        %ascii_set,
    },
    'bytes_unichar' => {
        'char_count' => 8,
        'bytes_size' => 10,
        %uni_set,
    },
    'unicode_unichar' => {
        'char_count' => 8,
        'bytes_size' => 10,
        %uni_set,
    },
    'b_grapheme_unichar' => {
        'char_count' => 8,
        'bytes_size' => 10,
        %uni_set,
    },
    'u_grapheme_unichar' => {
        'char_count' => 8,
        'bytes_size' => 10,
        %uni_set,
    },
);

is( escape_utf8_or_unicode("I \xe2\x99\xa5 perl"), 'I \xe2\x99\xa5 perl', 'escape_utf8_or_unicode() encodes as utf8 when given a utf8 string' );
is( escape_utf8_or_unicode("I \x{2665} perl"),     'I \x{2665} perl',     'escape_utf8_or_unicode() encodes as unicode when given a unicode string' );
is( escape_utf8("I \xe2\x99\xa5 perl"),            'I \xe2\x99\xa5 perl', 'escape_utf8() encodes as utf-8 bytes when given a utf8 string' );
is( escape_utf8("I \x{2665} perl"),                'I \xe2\x99\xa5 perl', 'escape_utf8() encodes as utf-8 bytes when given a unicode string' );
is( escape_unicode("I \xe2\x99\xa5 perl"),         'I \x{2665} perl',     'escape_unicode() encodes as unicode when given a utf8 string' );
is( escape_unicode("I \x{2665} perl"),             'I \x{2665} perl',     'escape_unicode() encodes as unicode when given a unicode string' );

ok( is_unicode( unescape_utf8_or_unicode('I \x{2665} perl') ),      'unescape_utf8_or_unicode return unicod when given unicode notation' );
ok( !is_unicode( unescape_utf8_or_unicode('I \xe2\x99\xa5 perl') ), 'unescape_utf8_or_unicode return utf8 bytes when given utf8 bytes notation' );
ok( !is_unicode( unescape_utf8('I \x{2665} perl') ),                'unescape_utf8() returns utf8 bytes when given unicode' );
ok( !is_unicode( unescape_utf8('I \xe2\x99\xa5 perl') ),            'unescape_utf8() returns utf8 bytes when given utf8 bytes' );
ok( is_unicode( unescape_unicode('I \x{2665} perl') ),              'unescape_unicode() return unicode when given unicode' );
ok( is_unicode( unescape_unicode('I \xe2\x99\xa5 perl') ),          'unescape_unicode() return unicode when given utf8 bytes' );

for my $var_name ( sort keys %test_strings ) {
    is( char_count( eval "\${$var_name}" ), $test_strings{$var_name}{'char_count'}, "char_count() for $var_name" );
    is( bytes_size( eval "\${$var_name}" ), $test_strings{$var_name}{'bytes_size'}, "bytes_size() for $var_name" );
    ok( is_unicode( get_unicode( eval "\${$var_name}" ) ), "get_unicode() returns unicode string for $var_name" );
    ok( !is_unicode( get_utf8( eval "\${$var_name}" ) ),   "get_utf8() returns bytes string for $var_name" );

    ok( !is_unicode( escape_utf8_or_unicode( eval "\${$var_name}" ) ), "escape_utf8_or_unicode() returns bytes string for $var_name" );
    ok( !is_unicode( escape_utf8( eval "\${$var_name}" ) ),            "escape_utf8() returns bytes string for $var_name" );
    ok( !is_unicode( escape_unicode( eval "\${$var_name}" ) ),         "escape_unicode() returns bytes string for $var_name" );

    is( quotemeta_bytes( eval "\${$var_name} . q{'s coolness}" ),   $test_strings{$var_name}{'quotemeta_bytes'},   "quotemeta_bytes() for $var_name" );
    is( quotemeta_utf8( eval "\${$var_name} . q{'s coolness}" ),    $test_strings{$var_name}{'quotemeta_utf8'},    "quotemeta_utf8() for $var_name" );
    is( quotemeta_unicode( eval "\${$var_name} . q{'s coolness}" ), $test_strings{$var_name}{'quotemeta_unicode'}, "quotemeta_unicode() for $var_name" );

    for my $q_type (qw(quotemeta_bytes quotemeta_utf8 quotemeta_unicode)) {
        ok( !is_unicode( unquotemeta_bytes( $test_strings{$var_name}{$q_type} ) ),  "unquotemeta_bytes() RV type given $q_type from $var_name" );
        ok( !is_unicode( unquotemeta_utf8( $test_strings{$var_name}{$q_type} ) ),   "unquotemeta_utf8() RV type given $q_type from $var_name" );
        ok( is_unicode( unquotemeta_unicode( $test_strings{$var_name}{$q_type} ) ), "unquotemeta_unicode() RV type given $q_type from $var_name" );

        is( unquotemeta_bytes( $test_strings{$var_name}{$q_type} ),   $test_strings{$var_name}{'unquotemeta_bytes'},   "unquotemeta_bytes() for $q_type via $var_name" );
        is( unquotemeta_utf8( $test_strings{$var_name}{$q_type} ),    $test_strings{$var_name}{'unquotemeta_utf8'},    "unquotemeta_utf8() for $q_type via $var_name" );
        is( unquotemeta_unicode( $test_strings{$var_name}{$q_type} ), $test_strings{$var_name}{'unquotemeta_unicode'}, "unquotemeta_unicode() for $q_type via $var_name" );
    }
}
