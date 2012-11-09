/** Additions to std.traits

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

For ranges, see also
$(LINK2 http://dlang.org/phobos/std_range.html#ElementEncodingType, std.range.ElementEncodingType).

Example:
---
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
Gets the rank (number of dimensions) of a static array type.

Example:
---
static assert(staticArrayDimensions!int == 0);
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
	static assert(staticArrayDimensions!int == 0);
	static assert(staticArrayDimensions!(int[]) == 0);
	static assert(staticArrayDimensions!string == 0);
	static assert(staticArrayDimensions!(int[0]) == 1);
	static assert(staticArrayDimensions!(int[7][8]) == 2);
	static assert(staticArrayDimensions!(int[0][]) == 0);
	static assert(staticArrayDimensions!(int[][0]) == 1);
	static assert(staticArrayDimensions!(int[0][0]) == 2);
}


/**
Gets the element type of the innermost array in a multidimensional static array type. 
Considers $(D T) to be an $(D n)-dimensional static array type.

Example:
---
static assert(is(MultidimensionalStaticArrayElementType!int == int));
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
	static assert(is(MultidimensionalStaticArrayElementType!int == int));
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
Calculates the total element count of a multidimensional static array.
Considers $(D T) to be an $(D n)-dimensional static array type.

Example:
---
static assert(multidimensionalStaticArrayElementsCount!int == 1);
static assert(multidimensionalStaticArrayElementsCount!(int[]) == 1);
static assert(multidimensionalStaticArrayElementsCount!(int[0]) == 0);
static assert(!__traits(compiles, multidimensionalStaticArrayElementsCount!(int[7][8], 3)));
static assert(multidimensionalStaticArrayElementsCount!(int[7][8]) == 7 * 8);
static assert(multidimensionalStaticArrayElementsCount!(int[7][8], 1) == 8);
static assert(multidimensionalStaticArrayElementsCount!(int[7][8], 0) == 1);
static assert(multidimensionalStaticArrayElementsCount!(int[0][]) == 1);
static assert(multidimensionalStaticArrayElementsCount!(int[][0]) == 0);
---
*/
template multidimensionalStaticArrayElementsCount(T, size_t n = staticArrayDimensions!T)
{
	static assert(staticArrayDimensions!T >= n, "Not enough static array dimensions");
	enum multidimensionalStaticArrayElementsCount = T.sizeof / MultidimensionalStaticArrayElementType!(T, n).sizeof;
}

unittest
{
	static assert(multidimensionalStaticArrayElementsCount!int == 1);
	static assert(multidimensionalStaticArrayElementsCount!(int[]) == 1);
	static assert(multidimensionalStaticArrayElementsCount!string == 1);
	static assert(multidimensionalStaticArrayElementsCount!(int[0]) == 0);
	static assert(!__traits(compiles, multidimensionalStaticArrayElementsCount!(int[7][8], 3)));
	static assert(multidimensionalStaticArrayElementsCount!(int[7][8]) == 7 * 8);
	static assert(multidimensionalStaticArrayElementsCount!(int[7][8], 1) == 8);
	static assert(multidimensionalStaticArrayElementsCount!(int[7][8], 0) == 1);
	static assert(multidimensionalStaticArrayElementsCount!(int[0][]) == 1);
	static assert(multidimensionalStaticArrayElementsCount!(int[][0]) == 0);
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
	static assert(Pack!(multidimensionalStaticArrayLengths!int).equals!());
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
Get all types $(D T) include except $(D Extracted) without duplicates
in such order that every compound type precedes types it includes.

Example:
---
static assert(is(ExtractTypes!int == TypeTuple!int));
static assert(is(ExtractTypes!(int*) == TypeTuple!(int*, int)));
static assert(is(ExtractTypes!(int*, int) == TypeTuple!(int*)));

struct S1 { int i; real r; }
static assert(is(ExtractTypes!S1 == TypeTuple!(S1, int, real)));
static assert(is(ExtractTypes!(S1, int) == TypeTuple!(S1, real)));

struct S2
{
	int* iptr;
	S1* s1ptr1, s1ptr2;
	S2[] s2darr;
	S2[3]* s2sarr;
}
static assert(is(ExtractTypes!S2 == TypeTuple!(
	S2,                // for `S2` itself
	int*, int,         // for `int*`
	S1*, S1, real,     // for `S1*`
	S2[],              // for `S2[]`
	S2[3]*, S2[3]      // for `S2[3]*`
)));
---
*/
template ExtractTypes(T, Extracted...) if(isTypeTuple!Extracted)
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
			alias TypeTuple!(T, NoDuplicates!(MapTuple!(Extract, FieldTypeTuple!T))) ExtractTypes;
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
	static assert(is(ExtractTypes!int == TypeTuple!int));
	static assert(is(ExtractTypes!(int*) == TypeTuple!(int*, int)));
	static assert(is(ExtractTypes!(int*, int) == TypeTuple!(int*)));
	static assert(!__traits(compiles, ExtractTypes!(int*, 0)));

	static struct S1 { int i; real r; }
	static assert(is(ExtractTypes!S1 == TypeTuple!(S1, int, real)));
	static assert(is(ExtractTypes!(S1, int) == TypeTuple!(S1, real)));

	static struct S2
	{
		int* iptr;
		S1* s1ptr1, s1ptr2;
		S2[] s2darr;
		S2[3]* s2sarr;
	}
	static assert(is(ExtractTypes!S2 == TypeTuple!(S2, int*, int, S1*, S1, real, S2[], S2[3]*, S2[3])));

	static class C { real n; }
	static assert(is(ExtractTypes!C == TypeTuple!(C, real)));

	static struct S3 { C c; S1* s1ptr1, s1ptr2; C* cptr; }
	static assert(is(ExtractTypes!S3 == TypeTuple!(S3, C, real, S1*, S1, int, C*)));
}


/**
true iff $(D T) is a type. Usable for analysing generic tuples.

Example:
---
static assert(isType!int && isType!string);
static assert(!isType!0 && !isType!"str");
static assert(!isType!isType);
---
*/
template isType(T)
{
	enum isType = true;
}

/// ditto
template isType(alias T)
{
	enum isType = false;
}

unittest
{
	static assert(isType!(int));
	static assert(isType!(int[]));
	static assert(isType!(string));
	static assert(isType!(TypeTuple!string));
	static assert(!__traits(compiles, isType!()));
	static assert(!__traits(compiles, isType!(int, string)));

	static assert(!isType!0);
	static assert(!isType!'a');
	static assert(!isType!"str");
	static assert(!isType!isType);

	static @property void __vp() { }
	static @property int __ip() { return 0; }
	static assert(!isType!(__vp));
	static assert(!isType!(__ip));

	static void __vf() { }
	static int __if() { return 0; }
	//static assert(!isType!(__vf())); //FIXME
	static assert(!isType!(__if()));
}
