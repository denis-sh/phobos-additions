﻿/** Additions to std.traits

Copyright: Denis Shelomovskij 2011-2012

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.traits;


public import std.traits;

import unstd.generictuple;
import std.typecons: tuple;


// https://github.com/D-Programming-Language/phobos/pull/776
/**
Returns the element type of an array.

For ranges, see also $(XREF range, ElementEncodingType).

Example:
---
import std.traits;
static assert(is(ArrayElementType!(int[]) == int));
static assert(is(ArrayElementType!string == immutable(char)));
static assert(is(ArrayElementType!(int[7][8]) == int[7]));
---
*/
template ArrayElementType(T : T[])
{
	alias T ArrayElementType;
}

unittest
{
	static assert( is(ArrayElementType!(int[]) == int));
	static assert( is(ArrayElementType!(long[0]) == long));
	static assert(is(ArrayElementType!string == immutable(char)));
	static assert(is(ArrayElementType!(int[7][8]) == int[7]));
	static assert(is(ArrayElementType!(int[0][]) == int[0]));
	static assert(is(ArrayElementType!(int[][0]) == int[]));

	static assert(!is(ArrayElementType!int));
}


/**
Get static array dimensions.

Example:
---
import std.traits;
static assert(staticArrayDimensions!(int[]) == 0);
static assert(staticArrayDimensions!(int[0]) == 1);
static assert(staticArrayDimensions!(int[7][8]) == 2);
static assert(staticArrayDimensions!(int[0][]) == 0);
static assert(staticArrayDimensions!(int[][0]) == 1);
---
*/
template staticArrayDimensions(T)
{
	static if(isStaticArray!T)
		enum staticArrayDimensions = 1 + staticArrayDimensions!(ArrayElementType!T);
	else
		enum staticArrayDimensions = 0;
}

unittest
{
	static assert(staticArrayDimensions!(int[]) == 0);
	static assert(staticArrayDimensions!string == 0);
	static assert(staticArrayDimensions!(int[0]) == 1);
	static assert(staticArrayDimensions!(int[7][8]) == 2);
	static assert(staticArrayDimensions!(int[0][]) == 0);
	static assert(staticArrayDimensions!(int[][0]) == 1);
	static assert(staticArrayDimensions!(int[0][0]) == 2);
}


/**
Get multidimensional static array element type considering 
$(D T) to be $(D n)-dimensioanl static array.

Example:
---
import std.traits;
static assert(is(MultidimensionalStaticArrayElementType!(int[]) == int[]));
static assert(is(MultidimensionalStaticArrayElementType!(int[0]) == int));
static assert(!__traits(compiles, MultidimensionalStaticArrayElementType!(int[7][8], 3)));
static assert(is(MultidimensionalStaticArrayElementType!(int[7][8]) == int));
static assert(is(MultidimensionalStaticArrayElementType!(int[7][8], 1) == int[7]));
static assert(is(MultidimensionalStaticArrayElementType!(int[7][8], 0) == int[7][8]));
static assert(is(MultidimensionalStaticArrayElementType!(int[0][]) == int[0][]));
static assert(is(MultidimensionalStaticArrayElementType!(int[][0]) == int[]));
---
*/
template MultidimensionalStaticArrayElementType(T, size_t n = staticArrayDimensions!T)
{
	static assert(staticArrayDimensions!T >= n, "Not enough static array dimensions");
	static if(n)
		alias MultidimensionalStaticArrayElementType!(ArrayElementType!T, n-1) MultidimensionalStaticArrayElementType;
	else
		alias T MultidimensionalStaticArrayElementType;
}

unittest
{
	static assert(is(MultidimensionalStaticArrayElementType!(int[]) == int[]));
	static assert(is(MultidimensionalStaticArrayElementType!string == string));
	static assert(is(MultidimensionalStaticArrayElementType!(int[0]) == int));
	static assert(!__traits(compiles, MultidimensionalStaticArrayElementType!(int[7][8], 3)));
	static assert(is(MultidimensionalStaticArrayElementType!(int[7][8]) == int));
	static assert(is(MultidimensionalStaticArrayElementType!(int[7][8], 1) == int[7]));
	static assert(is(MultidimensionalStaticArrayElementType!(int[7][8], 0) == int[7][8]));
	static assert(is(MultidimensionalStaticArrayElementType!(int[0][]) == int[0][]));
	static assert(is(MultidimensionalStaticArrayElementType!(int[][0]) == int[]));
}


/**
Get, as an expression tuple, multidimensional static array lengths considering
$(D T) to be $(D n)-dimensioanl static array.

Example:
---
alias multidimensionalStaticArrayLengths!(int[7][8]) e1;
static assert(e1.length == 2 && e1[0] == 8 && e1[1] == 7);

alias multidimensionalStaticArrayLengths!(int[7][8], 1) e2;
static assert(e2.length == 1 && e2[0] == 8);
static assert(multidimensionalStaticArrayLengths!(int[7][8], 0).length == 0);
---
*/
template multidimensionalStaticArrayLengths(T, size_t n = staticArrayDimensions!T)
{
	static assert(staticArrayDimensions!T >= n, "Not enough static array dimensions");

	static if(n)
		alias expressionTuple!(T.length, multidimensionalStaticArrayLengths!(ArrayElementType!T, n-1)) multidimensionalStaticArrayLengths;
	else
		alias expressionTuple!() multidimensionalStaticArrayLengths;
}

unittest
{
	static assert(Pack!(multidimensionalStaticArrayLengths!(int[])).equals!());
	static assert(Pack!(multidimensionalStaticArrayLengths!string).equals!());
	static assert(Pack!(multidimensionalStaticArrayLengths!(int[0])).equals!(0));
	static assert(!__traits(compiles, multidimensionalStaticArrayLengths!(int[7][8], 3)));
	static assert(Pack!(multidimensionalStaticArrayLengths!(int[7][8])).equals!(8, 7));
	static assert(Pack!(multidimensionalStaticArrayLengths!(int[7][8], 1)).equals!(8));
	static assert(Pack!(multidimensionalStaticArrayLengths!(int[7][8], 0)).equals!());
	static assert(Pack!(multidimensionalStaticArrayLengths!(int[0][])).equals!());
	static assert(Pack!(multidimensionalStaticArrayLengths!(int[][0])).equals!(0));
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
