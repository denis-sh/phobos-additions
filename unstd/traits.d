/** Additions to std.traits

Copyright: Denis Shelomovskij 2011-2012

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.traits;


public import std.traits;

import unstd.generictuple;


// https://github.com/D-Programming-Language/phobos/pull/776
/**
Returns the element type of an array.
*/
template ArrayElementType(T : T[])
{
	alias T ArrayElementType;
}

unittest
{
	static assert( is(ArrayElementType!(int[]) == int));
	static assert( is(ArrayElementType!(long[0]) == long));

	static assert(!is(ArrayElementType!int));
}


/**
TODO docs
*/
template ExtractTypes(T, Extracted...)
{
	static if(staticIndexOf!(T, Extracted) != -1)
	{
		alias TypeTuple!() ExtractTypes;
	}
	else
	{
		static assert(!is(T == typedef), "typedef-s aren't supported by ExtractTypes.");

		template Extract(U)
		{
			alias .ExtractTypes!(U, Extracted, T) Extract;
		}

		static if(is(PointerTarget!T PT))
		{
			alias TypeTuple!(T, Extract!PT) ExtractTypes;
		}
		else static if(__traits(isScalar, T))
		{
			alias TypeTuple!T ExtractTypes;
		}
		else static if(is(T == struct) || is(T == class) || is(T == union))
		{
			alias TypeTuple!(T, NoDuplicates!(TemplateMap!(Extract, FieldTypeTuple!T))) ExtractTypes;
		}
		else static if(isArray!T)
		{
			alias TypeTuple!(T, Extract!(ArrayElementType!T)) ExtractTypes;
		}
		else
			static assert(0);
	}
}

unittest
{
	static struct S1 { int i; real r; }
	static assert(Pack!(ExtractTypes!S1).equals!(S1, int, real));

	static struct S2
	{
		int* iptr;
		S1* s1ptr1, s1ptr2;
		S2[] s2darr;
		S2[3]* s2sarr;
	}
	static assert(Pack!(ExtractTypes!S2).equals!(S2, int*, int, S1*, S1, real, S2[], S2[3]*, S2[3]));

	static class C { real n; }
	static assert(Pack!(ExtractTypes!C).equals!(C, real));

	static struct S3 { C c; S1* s1ptr1, s1ptr2; C* cptr; }
	static assert(Pack!(ExtractTypes!S3).equals!(S3, C, real, S1*, S1, int, C*));
}
