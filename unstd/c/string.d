/** Helper functions for working with $(I C strings).

Copyright: Denis Shelomovskij 2013

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.c.string;


import std.traits;
import unstd.utf;
version(unittest) import unstd.generictuple;


/// Returns $(I C string) length. If $(D cstr) is null returns 0.
size_t getLength(C)(in C* cstr) pure nothrow
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
	assert(!(cast(char*) null).getLength());
	assert(!"".ptr.getLength());
	foreach(s; expressionTuple!("abc", "abc"w, "abc"d))
		assert(s.ptr.getLength() == 3);
}


/**
Returns array representing $(I C string) where $(D '\0') character is placed
after the end of the array. If $(D cstr) is null returns null.
*/
inout(C)[] asArray(C)(inout C* cstr) pure nothrow
if(isSomeChar!C)
{
	if(!cstr)
		return null;

	return cstr[0 .. cstr.getLength()];
}

unittest
{
	foreach(s; expressionTuple!(cast(char[]) null, "", "abc", "abc"w, "abc"d))
	{
		auto var = s; // Have to assign to variable first.
		assert(var.ptr.asArray() is var);
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
	const arr = cstr.asArray();
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
