/** Additions to $(STDMODULE _utf).

Copyright: Denis Shelomovskij 2012-2013

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.utf;


version(D_NoBoundsChecks) { }
else import core.exception;

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


/**
Copies text from $(D source) to $(D destinition) performing conversion
to different unicode transformation format if needed.

$(D destinition) must be large enough to hold the result.

Preconditions:
$(D destinition.length >= minLength!To(source))
*/
void copyEncoded(To, From)(in From[] source, ref To[] destinition)
if(isSomeChar!To && isSomeChar!From)
in { assert(destinition.length >= minLength!To(source)); }
body
{
	static if(is(To == From))
	{
		destinition = destinition[0 .. source.length] = source[];
	}
	else
	{
		To* ptr = destinition.ptr;
		const To* last = ptr + destinition.length;
		foreach(dchar dc; source)
		{
			version(D_NoBoundsChecks) { }
			else if(ptr + codeLength!To(dc) > last)
				onRangeError();

			static if(is(To == dchar))
				*ptr++ = dc;
			else
				// Warning: assume `encode` uses only needed bytes.
				ptr += encode(*(cast(To[4 / To.sizeof]*) ptr), dc);
		}
		destinition = destinition[0 .. ptr - destinition.ptr];
	}
}

///
unittest
{
	const str = "abc-ЭЮЯ";
	wchar[100] wsbuff;
	auto wstr = wsbuff[];
	copyEncoded(str, wstr);
	assert(wstr == "abc-ЭЮЯ"w);
}

unittest
{
	wchar[100] wsbuff;
	auto wstr = wsbuff[];
	copyEncoded("abc-ЭЮЯ"w, wstr);
	assert(wstr == "abc-ЭЮЯ"w);
}

unittest
{
	import std.range;

	const str = "abc-ЭЮЯ";
	char[100] sbuff;

	{
		wchar[100] wsbuff;
		auto wstr = wsbuff[0 .. toUTF16(str).length];
		copyEncoded(str, wstr);
		assert(wstr == toUTF16(str));

		auto str2 = sbuff[0 .. str.length];
		copyEncoded(wstr, str2);
		assert(str2 == str);
	}
	{
		dchar[100] dsbuff;
		auto dstr = dsbuff[0 .. walkLength(str)];
		copyEncoded(str, dstr);
		assert(dstr == toUTF32(str));

		auto str2 = sbuff[0 .. str.length];
		copyEncoded(dstr, str2);
		assert(str2 == str);
	}
}
