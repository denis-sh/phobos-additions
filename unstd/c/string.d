/** Helper functions for working with $(I C strings).

This module is intended to provide fast, safe and garbage free
way to work with $(I C strings).

Examples:
---
version(Posix):

import core.stdc.stdlib: free;
import core.sys.posix.unistd: getcwd;
import core.sys.posix.stdlib: getenv, setenv;
import std.exception: enforce;

@property string cwd()
{ return enforce(getcwd(null, 0).moveToString!free()); }

string getEnvironment(in char[] name)
{ return enforce(getenv(name.tempCString()).toString()); }

void setEnvironment(in char[] name, in char[] value)
{ enforce(setenv(name.tempCString(), value.tempCString(), 1) != -1); }
---
---
version(Windows):

import core.sys.windows.windows: SetEnvironmentVariableW;
import std.exception: enforce;

void setEnvironment(in char[] name, in char[] value)
{ enforce(SetEnvironmentVariableW(name.tempCString!wchar(), value.tempCString!wchar())); }
---

Copyright: Denis Shelomovskij 2013

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij

Macros:
COREREF = $(HTTP dlang.org/phobos/core_$1.html#$2, $(D core.$1.$2))
*/
module unstd.c.string;


import core.exception;

import std.traits;
import unstd.utf;
version(unittest) import unstd.generictuple;
import unstd.memory.allocation;


/// Returns $(I C string) length. If $(D cstr) is null returns 0.
@property size_t length(C)(in C* cstr) pure nothrow
if(isSomeChar!C)
{
	if(!cstr)
		return 0;
	size_t res = 0;
	while(cstr[res])
		++res;
	return res;
}

unittest
{
	assert(!(cast(char*) null).length);
	assert(!"".ptr.length);
	foreach(s; expressionTuple!("abc", "abc"w, "abc"d))
		assert(s.ptr.length == 3);
}


/**
Compare $(I C strings) lexicographically.

Preconditions:
$(D cstr1 != null && cstr2 != null)
*/
@property int cmpCStrings(C)(in C* cstr1, in C* cstr2) pure nothrow
if(isSomeChar!C)
in { assert(cstr1 && cstr2); }
body
{
	if(cstr1 == cstr2)
		return 0;
	for(size_t i = 0; ; ++i)
	{
		const c1 = cstr1[i], c2 = cstr2[i];
		if(!c1 && !c2)
			return 0;
		if(c1 != c2)
			return c1 > c2 ? 1 : -1;
	}
}

///
unittest
{
	assert(cmpCStrings("ab".ptr, "ab".ptr) == 0);
	assert(cmpCStrings("ab".ptr, "abc".ptr) < 0);
	assert(cmpCStrings("abc".ptr, "ab".ptr) > 0);
}

unittest
{
	string prev = null;
	foreach(s; ["", "a", "abc", "abcd", "я"])
	{
		assert(cmpCStrings(s.ptr, s.ptr) == 0);
		assert(cmpCStrings(s.ptr, (s ~ '\0').dup.ptr) == 0);
		if(prev)
		{
			assert(cmpCStrings(prev.ptr, s.ptr) == -1);
			assert(cmpCStrings(s.ptr, prev.ptr) == 1);
		}
		prev = s;
	}
}


/**
Returns array representing $(I C string) where $(D '\0') character is placed
after the end of the array. If $(D cstr) is null returns null.
*/
@property inout(C)[] asArray(C)(inout C* cstr) pure nothrow
if(isSomeChar!C)
{
	if(!cstr)
		return null;

	return cstr[0 .. cstr.length];
}

unittest
{
	foreach(s; expressionTuple!(cast(char[]) null, "", "abc", "abc"w, "abc"d))
	{
		auto var = s; // Have to assign to variable first.
		assert(var.ptr.asArray is var);
	}
}


/**
Creates GC-allocated $(D string) with copy of $(I C string) text.
If $(D cstr) is null returns null, otherwise if $(D cstr) is empty
returns $(D "").
*/
string toString(C)(in C* cstr) pure
if(isSomeChar!C)
{
	if(!cstr)
		return null;
	if(!*cstr)
		return "";
	const arr = cstr.asArray;
	static if(is(C == char))
		return arr.idup;
	else
		return arr.toUTF8();
}

unittest
{
	foreach(s; expressionTuple!(cast(char[]) null, "", "abc", "abc"w, "abc"d))
		assert(s.ptr.toString() == s.toUTF8());
}


/**
Creates $(I C string) allocated using $(D tryAllocate) with copy of $(D str).
If $(D str) is null returns null.

$(D tryAllocate) is assumed to return properly aligned for $(D To) memory or
null if allocation fails.

If allocation fails toCString will call $(COREREF exception, onOutOfMemoryError)
which is expected to throw an $(COREREF exception, OutOfMemoryError).
*/
To* toCString(alias tryAllocate, To = char, From)(in From[] str)
if(isSomeChar!To && isSomeChar!From)
{
	if(!str)
		return null;

	const maxLen = maxLength!To(str);
	To* cstr = null;
	if(const totalCount = memoryAdd(maxLen, 1))
		if(const totalBytes = memoryMult(To.sizeof, totalCount))
			cstr = cast(To*) tryAllocate(totalBytes);
	if(!cstr)
		onOutOfMemoryError();
	To[] carr = cstr[0 .. maxLen];
	copyEncoded(str, carr);
	*(cstr + carr.length) = '\0';
	return cstr;
}

///
unittest
{
	import core.stdc.stdlib;
	import core.stdc.string;

	string str = "abc";

	char* cstr = str.toCString!malloc();
	scope(exit) free(cstr);
	assert(strlen(cstr) == 3);
}

unittest
{
	import core.stdc.stdlib;

	assert("abc".toCString!malloc().moveToString!free() == "abc");
	assert("abc"d.toCString!malloc().moveToString!free() == "abc");
	assert("abc".toCString!(malloc, wchar)().moveToString!free() == "abc");
}


/**
Returns same as $(MREF toString) but also if $(D cstr) is not null
releases its memory calling $(D release(cast(void*) cstr)).
*/
string moveToString(alias release, C)(C* cstr)
if(isSomeChar!C)
{
	scope(exit) if(cstr) release(cast(void*) cstr);
	return cstr.toString();
}

unittest
{
	import core.stdc.stdlib;

	auto cstr = cast(char*) malloc(4);
	assert(cstr);
	cstr[0 .. 4] = "abc\0";
	assert(cstr.moveToString!free() == "abc");
}


/**
Creates temporary $(I C string) with copy of passed text.

Returned object is implicitly convertible to $(D const To*) and
has two properties: $(D ptr) to access $(I C string) as $(D const To*)
and $(D buffPtr) to access it as $(D To*).

The temporary $(I C string) is valid unless returned object is destroyed.
Thus if returned object is assigned to a variable the temporary is
valid unless the variable goes out of scope. If returned object isn't
assigned to a variable it will be destroyed at the end of creating
primary expression.

Note:
This function is intended to be used in function call expression (like
$(D strlen(str.tempCString()))). Incorrect usage of this function may
lead to memory corruption.
See $(RED WARNING) in $(B Examples) section.
*/
auto tempCString(To = char, From)(in From[] str)
if(isSomeChar!To && isSomeChar!From)
{
	static struct Res
	{
		@disable this();
		@disable this(this);
		alias ptr this;

		@property inout(To)* buffPtr() inout
		{ return _ptr; }

		@property const(To)* ptr() const
		{ return _ptr; }

		~this()
		{ cHeap.rawFree(_ptr); }

	private:
		To* _ptr;

		this(To* ptr)
		{ _ptr = ptr; }
	}

	if(!str)
		return Res(null);

	const totalCount = memoryAdd(maxLength!To(str), 1);
	if(!totalCount)
		onOutOfMemoryError();
	To[] arr = cHeap.allocate!To(totalCount)[0 .. $ - 1];
	copyEncoded(str, arr);
	*(arr.ptr + arr.length) = '\0';
	return Res(arr.ptr);
}

///
unittest
{
	import core.stdc.string;

	string str = "abc";

	// Intended usage
	assert(strlen(str.tempCString()) == 3);

	// Correct usage
	auto tmp = str.tempCString();
	assert(strlen(tmp) == 3); // or `tmp.ptr`, or `tmp.buffPtr`

	// $(RED WARNING): $(RED Incorrect usage)
	auto pInvalid1 = str.tempCString().ptr;
	const char* pInvalid2 = str.tempCString();
	// Both pointers refer to invalid memory here as
	// returned values aren't assigned to a variable and
	// both primary expressions are ended.
}

unittest
{
	assert("abc".tempCString().asArray == "abc");
	assert("abc"d.tempCString().ptr.asArray == "abc");
	assert("abc".tempCString!wchar().buffPtr.asArray == "abc"w);
}
