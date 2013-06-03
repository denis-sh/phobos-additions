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


@safe:

/// Detect whether $(D c) is a UTF-8 continuation byte.
bool isContinuationByte(in char c) pure nothrow
{
	return (c & 0xC0) == 0x80;
}

/// Detect whether $(D c) is a UTF-16 lead/trail surrogate or not a surrogate.
bool isLeadSurrogate(in wchar c) pure nothrow
{
	return c >= 0xD800 && c < 0xDC00;
}

/// ditto
bool isTrailSurrogate(in wchar c) pure nothrow
{
	return c >= 0xDC00 && c < 0xE000;
}

/// ditto
bool isValidBMPCharacter(in wchar c) pure nothrow
{
	return c < 0xD800 || c >= 0xE000;
}

unittest
{
	import unstd.generictuple;

	foreach(c; "zд"w)
	{
		assert(!isLeadSurrogate(c));
		assert(!isTrailSurrogate(c));
		assert( isValidBMPCharacter(c));
	}

	foreach(i, c; "\U00010143"w)
	{
		assert(isLeadSurrogate(c) == !i);
		assert(isTrailSurrogate(c) == i);
		assert(!isValidBMPCharacter(c));
	}
}


/// Detect whether $(D c) is the first code unit in a sequence.
bool isSequenceStart(C)(in C c) pure nothrow
if(isSomeChar!C)
{
	static if(is(C : char))
		return !isContinuationByte(c);
	else static if(is(C : wchar))
		return !isTrailSurrogate(c);
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
size_t adjustBack(C)(in C[] str, size_t idx) pure nothrow
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
				if(!isContinuationByte(str[idx]))
					return idx;
				assert(idx, "String starts from UTF-8 continuation byte.");
				--idx;
			}
			assert(!isContinuationByte(str[idx]), "UTF-8 sequence length exceeds 4 bytes.");
		}
	}
	else static if(is(C : wchar))
	{
		if(idx != str.length && isTrailSurrogate(str[idx]))
		{
			assert(idx, "String starts from UTF-16 trail surrogate.");
			--idx;
			assert(isLeadSurrogate(str[idx]), "UTF-16 lead surrogate expected before trail surrogate.");
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
size_t adjustForward(C)(in C[] str, size_t idx) pure nothrow
in { assert(idx <= str.length); }
body
{
	static if(is(C : char))
	{
		if(idx != str.length)
		{
			foreach(_; 0 .. 4 - 1) // Don't expect 5 and 6 byte combinations
			{
				if(idx == str.length || !isContinuationByte(str[idx]))
					return idx;
				++idx;
			}
			assert(idx == str.length || !isContinuationByte(str[idx]), "UTF-8 sequence length exceeds 4 bytes.");
		}
	}
	else static if(is(C : wchar))
	{
		if(idx != str.length && isTrailSurrogate(str[idx]))
		{
			++idx;
			assert(idx == str.length || isLeadSurrogate(str[idx]), "UTF-16 lead surrogate expected after trail surrogate.");
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
size_t minLength(To, From)(in size_t length) pure nothrow
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
size_t minLength(To, From)(in From[] str) pure nothrow
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
size_t maxLength(To, From)(in size_t length) pure nothrow
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
size_t maxLength(To, From)(in From[] str) pure nothrow
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
Copies text from $(D source) to $(D buff) performing conversion
to different unicode transformation format if needed.

$(D buff) must be large enough to hold the result.

Preconditions:
$(D buff.length >= minLength!To(source))

Returns:
Slice of the provided buffer $(D buff) with the copy of $(D source).
*/
To[] copyEncoded(To, From)(in From[] source, To[] buff) @trusted
if(isSomeChar!To && isSomeChar!From)
in { assert(buff.length >= minLength!To(source)); }
body
{
	static if(is(Unqual!To == Unqual!From))
	{
		return buff[0 .. source.length] = source[];
	}
	else
	{
		To* ptr = buff.ptr;
		const To* last = ptr + buff.length;
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
		return buff[0 .. ptr - buff.ptr];
	}
}

///
unittest
{
	const str = "abc-ЭЮЯ";
	wchar[100] wsbuff;
	assert(copyEncoded(str, wsbuff) == "abc-ЭЮЯ"w);
}

unittest
{
	wchar[100] wsbuff;
	assert(copyEncoded("abc-ЭЮЯ"w, wsbuff) == "abc-ЭЮЯ"w);
}

unittest
{
	import std.range;

	const str = "abc-ЭЮЯ";
	char[100] sbuff;

	{
		wchar[100] wsbuff;
		const strW = toUTF16(str);
		assert(copyEncoded(str, wsbuff[0 .. strW.length]) == strW);
		assert(copyEncoded(strW, sbuff[0 .. str.length]) == str);
	}
	{
		dchar[100] dsbuff;
		const strD = toUTF32(str);
		assert(copyEncoded(str, dsbuff[0 .. walkLength(str)]) == strD);
		assert(copyEncoded(strD, sbuff[0 .. str.length]) == str);
	}
}


/**
Copies as much text from the beginning of $(D source) to $(D buff) as latter can hold
performing conversion to different unicode transformation format if needed.

$(D source) will be set to its uncopied slice.

Returns:
Slice of the provided buffer $(D buff) with a (parital) copy of $(D source).

Examples:
---
import std.array: empty;

const(char)[] buff = ...;
wchar[n] wbuff = void;
while(!buff.empty)
	f(buff.copySomeEncoded(wbuff)); // `f` accepts at most `n` wide characters
---
*/
To[] copySomeEncoded(To, From)(ref inout(From)[] source, To[] buff) @trusted pure
if(isSomeChar!To && isSomeChar!From)
{
	static if(is(Unqual!To == Unqual!From))
	{
		const length = source.length <= buff.length ? source.length : source.adjustBack(buff.length);
		auto res = buff[0 .. length] = source[0 .. length];
		source = source[length .. $];
		return res;
	}
	else
	{
		To* ptr = buff.ptr;
		const To* last = ptr + buff.length;
		size_t end = -1;
		foreach(i, dchar dc; source)
		{
			if(ptr + codeLength!To(dc) > last)
			{
				end = i;
				break;
			}

			static if(is(Unqual!To == dchar))
				*ptr++ = dc;
			else
				// Warning: assume `encode` uses only needed bytes.
				ptr += encode(*(cast(To[4 / To.sizeof]*) ptr), dc);
		}
		source = source[end == -1 ? $ : end .. $];
		return buff[0 .. ptr - buff.ptr];
	}
}

unittest
{
	import std.array: empty;
	import unstd.generictuple;

	foreach(str; expressionTuple!("abcdef", "zэюяzzэюяzzэюя", "z\U00010143z"))
		foreach(f; GenericTuple!(s => s, toUTF16, toUTF32))
		{
			foreach(n; expressionTuple!(2, 3, 4, 10))
			{
				auto buff = f(str);
				wchar[] allWchars;
				wchar[n] wbuff = void;
				while(!buff.empty)
					allWchars ~= buff.copySomeEncoded(wbuff[]);
				assert(allWchars == str.toUTF16());
			}
		}
}
