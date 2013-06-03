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


/// Detect whether $(D c) is the first code unit in a sequence.
bool isSequenceStart(C)(in C c)
if(isSomeChar!C)
{
	static if(is(C : char))
		return (c & 0xC0) != 0x80; // Not a UTF-8 continuation byte
	else static if(is(C : wchar))
		return !(c >= 0xDC00 && c < 0xE000); // Not a UTF-16 trail surrogate
	else static if(is(C : dchar))
		return true; // Always true
	else
		static assert(0);
}

unittest
{
	import unstd.generictuple;

	foreach(str; expressionTuple!("a", "a"w, "a"d, "д", "д"w, "д"d, "\U00010143"w, "\U00010143"d))
		assert(isSequenceStart(str[0]));

	assert(!isSequenceStart("д"[1]));
	assert(!isSequenceStart("\U00010143"w[1]));
}


/**
Adjust $(D idx) to point at the start of a UTF sequence or
at the end of $(D str).
*/
size_t adjustBack(C)(in C[] str, size_t idx)
if(isSomeChar!C)
in { assert(idx <= str.length); }
body
{
	static if(is(C : char))
	{
		if(idx != str.length)
		{
			foreach(_; 0 .. 4 - 1) // Don't expect 5 and 6 byte combinations
			{
				if(isSequenceStart(str[idx]))
					return idx;
				assert(idx, "String starts from UTF-8 continuation byte.");
				--idx;
			}
			assert(isSequenceStart(str[idx]), "UTF-8 sequence length exceeds 4 bytes.");
		}
	}
	else static if(is(C : wchar))
	{
		if(idx != str.length && !isSequenceStart(str[idx]))
		{
			assert(idx, "String starts from UTF-16 trail surrogate.");
			--idx;
			assert(isSequenceStart(str[idx]), "UTF-16 lead surrogate expected before trail surrogate.");
		}
	}
	else
	{
		static assert(is(C : dchar));
	}

	return idx;
}

unittest
{
	assert("a".adjustBack(0) == 0);
	assert("a".adjustBack(1) == 1);
	assert("ab".adjustBack(1) == 1);
	assert("д".adjustBack(1) == 0);
	assert("дb".adjustBack(2) == 2);
	foreach(i; 0 .. 4)
		assert("\U00010143".adjustBack(i) == 0);
	assert("\U00010143".adjustBack(4) == 4);
	assert("\U00010143"w.adjustBack(1) == 0);
}

/// ditto
size_t adjustForward(C)(in C[] str, size_t idx)
in { assert(idx <= str.length); }
body
{
	static if(is(C : char))
	{
		if(idx != str.length)
		{
			foreach(_; 0 .. 4 - 1) // Don't expect 5 and 6 byte combinations
			{
				if(idx == str.length || isSequenceStart(str[idx]))
					return idx;
				++idx;
			}
			assert(idx == str.length || isSequenceStart(str[idx]), "UTF-8 sequence length exceeds 4 bytes.");
		}
	}
	else static if(is(C : wchar))
	{
		if(idx != str.length && !isSequenceStart(str[idx]))
		{
			++idx;
			assert(idx == str.length || isSequenceStart(str[idx]), "UTF-16 lead surrogate expected after trail surrogate.");
		}
	}
	else
	{
		static assert(is(C : dchar));
	}

	return idx;
}

unittest
{
	assert("a".adjustForward(0) == 0);
	assert("a".adjustForward(1) == 1);
	assert("ab".adjustForward(1) == 1);
	assert("д".adjustForward(1) == 2);
	assert("дb".adjustForward(2) == 2);
	assert("\U00010143".adjustForward(0) == 0);
	foreach(i; 1 .. 5)
		assert("\U00010143".adjustForward(i) == 4);
	assert("\U00010143"w.adjustForward(1) == 2);
}


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
	static if(is(Unqual!To == Unqual!From))
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

			static if(is(Unqual!To == dchar))
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
