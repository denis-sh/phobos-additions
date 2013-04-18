/** Additions to $(STDMODULE _utf).

Copyright: Denis Shelomovskij 2012-2013

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.utf;


import std.traits;
public import std.utf;


/**
Returns minimum/maximum possible length of string conversion
to another Unicode Transformation Format result.
*/
size_t minLength(To, From)(in size_t length) @safe pure nothrow
if(isSomeChar!To && isSomeChar!From)
{
	static if (To.sizeof <= From.sizeof)
		return length; // best case: every character requires ony one code unit

	// n / m + !!(n % m) == (n + m-1) / m
	else static if (To.sizeof == 4 && From.sizeof == 2)
		return (length + 1) / 2; // best case: only surrogate pairs
	else static if (To.sizeof == 4 && From.sizeof == 1)
		return (length + 3) / 4; // best case: every dchar not in BMP
	else static if (To.sizeof == 2 && From.sizeof == 1)
		return (length + 2) / 3; // best case: every wchar in top of BMP
	else
		static assert(0);
}

/// ditto
size_t minLength(To, From)(in From[] str) @safe pure nothrow
{ return minLength!(To, From)(str.length); }

unittest
{
	assert(minLength!char("abc"d) == 3);
	assert(minLength!dchar("ab"w) == 1);
	assert(minLength!dchar("abc"w) == 2);
	assert(minLength!dchar("abcd"w) == 2);
	assert(minLength!dchar("abcd") == 1);
	assert(minLength!dchar("abcde") == 2);
	assert(minLength!dchar("abcdef") == 2);
	assert(minLength!dchar("abcdefg") == 2);
	assert(minLength!dchar("abcdefgh") == 2);
	assert(minLength!dchar("abcdefghi") == 3);
	assert(minLength!wchar("abc") == 1);
	assert(minLength!wchar("abcd") == 2);
	assert(minLength!wchar("abcde") == 2);
	assert(minLength!wchar("abcdef") == 2);
	assert(minLength!wchar("abcdefg") == 3);
}


/// ditto
size_t maxLength(To, From)(in size_t length) @safe pure nothrow
if(isSomeChar!To && isSomeChar!From)
{
	static if (To.sizeof >= From.sizeof)
		enum k = 1; // worst case: every code unit represents a character
	else static if (To.sizeof == 1 && From.sizeof == 2)
		enum k = 3; // worst case: every wchar in top of BMP
	else static if (To.sizeof == 1 && From.sizeof == 4)
		enum k = 4; // worst case: every dchar not in BMP
	else static if (To.sizeof == 2 && From.sizeof == 4)
		enum k = 2; // worst case: every dchar not in BMP
	else
		static assert(0);
	return length * k;
}

/// ditto
size_t maxLength(To, From)(in From[] str) @safe pure nothrow
{ return maxLength!(To, From)(str.length); }

unittest
{
	assert(maxLength!char("abc") == 3);
	assert(maxLength!dchar("abc") == 3);
	assert(maxLength!char("abc"w) == 9);
	assert(maxLength!char("abc"d) == 12);
	assert(maxLength!wchar("abc"d) == 6);
}


///
unittest
{
	import std.range;
	import std.utf;

	const str = "abc-ЭЮЯ";
	const wlen = toUTF16(str).length;
	const dlen = walkLength(str);
	assert(wlen >= minLength!wchar(str) && wlen <= maxLength!wchar(str));
	assert(dlen >= minLength!dchar(str) && dlen <= maxLength!dchar(str));
}
