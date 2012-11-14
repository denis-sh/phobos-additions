/** Additions to std.array.

Copyright: Denis Shelomovskij 2011-2012

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.array;


public import std.array;

import unstd.traits;


/**
Represents value as a flat (single-dimention) static array.
Considers $(D T) to be an $(D n)-dimensional static array type.

See also
$(DPREF traits, MultidimensionalStaticArrayElementType),
$(DPREF traits, multidimensionalStaticArrayElementsCount).

Example:
---
int i;
static assert(is(typeof(asFlatStaticArray(i)) == int[1]));
asFlatStaticArray(i) = 5;
assert(i == 5);

int[1][2][3] mdimSArr;
static assert(is(typeof(asFlatStaticArray(mdimSArr)) == int[6]));
asFlatStaticArray(mdimSArr) = [1, 2, 3, 4, 5, 6];
assert(mdimSArr == [[[1], [2]], [[3], [4]], [[5], [6]]]);

static assert(is(typeof(asFlatStaticArray!2(mdimSArr)) == int[1][6]));
assert(asFlatStaticArray!2(mdimSArr) == [[1], [2], [3], [4], [5], [6]]);
---
*/
ref asFlatStaticArray(T, size_t n = staticArrayDimensions!T)(ref T t)
{
	return *(cast(MultidimensionalStaticArrayElementType!(T, n)
		[multidimensionalStaticArrayElementsCount!(T, n)]*) &t);
}

/// ditto
ref asFlatStaticArray(size_t n, T)(ref T t)
{
	return asFlatStaticArray!(T, n)(t);
}

unittest
{
	int i;
	static assert(is(typeof(asFlatStaticArray(i)) == int[1]));
	asFlatStaticArray(i) = 5;
	assert(i == 5);

	int[1][2][3] mdimSArr;
	static assert(is(typeof(asFlatStaticArray(mdimSArr)) == int[6]));
	asFlatStaticArray(mdimSArr) = [1, 2, 3, 4, 5, 6];
	assert(mdimSArr == [[[1], [2]], [[3], [4]], [[5], [6]]]);

	static assert(is(typeof(asFlatStaticArray!2(mdimSArr)) == int[1][6]));
	assert(asFlatStaticArray!2(mdimSArr) == [[1], [2], [3], [4], [5], [6]]);
}

unittest
{
	static void test(T, U, El, V, W)(U valInit, El[] sarrFrom, V arrAssign, W valNew)
	{
		T t = valInit;
		auto p = &asFlatStaticArray(t);
		assert(cast(void*) p == &t);
		static assert((*p).sizeof == T.sizeof);
		assert(*p == sarrFrom);
		*p = arrAssign;
		assert(t == valNew);
	}

	test!int(3, [3],  4 , 4);
	test!int(3, [3], [4], 4);

	test!(int[0])(null, [], null, []);
	test!(int[0])( 3, [], null, []);
	test!(int[0])( 3, [],  4, []);

	test!(int[2])([3, 4], [3, 4], [5, 6], [5, 6]);
	test!(int[2])(3, [3, 3], 1, [1, 1]);
}
