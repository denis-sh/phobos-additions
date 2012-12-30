/** Additions to $(STDMODULE _array).

Copyright: Denis Shelomovskij 2011-2012

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.array;


import core.stdc.string;
public import std.array;

import unstd.generictuple;
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


/**
Binary copies $(D src) to $(D dest). $(D src) and $(D dest) can overlap.

This function is a preffered way over $(I C)'s $(D memcpy) and $(D memmove) as
it's CTFE-able and can work faster than $(I C)'s ones as it knows data type.
*/
void rawCopy(T)(const ref T src, ref T dest) nothrow
{
	if(__ctfe)
	{
		rawCopyCTImpl(src, dest);
	}
	else static if(T.sizeof == 16 || T.sizeof == 12 || (T.sizeof < 11 && T.sizeof != 7))
	{
		// Optimization for structs <= 16 bytes except for sizes 7, 11, 13-15.

		alias GenericTuple!(byte, short, int, 0, long) Types;

		enum bytes1 = {
			foreach(bytes1; [8, 4, 2, 1])
				foreach(bytes2; [0, 1, 2, 4, 8])
					if(bytes1 + bytes2 == T.sizeof)
						return bytes1;
			assert(0);
		}();
		enum bytes2 = T.sizeof - bytes1;

		alias Types[bytes1 / 2] U;

		static if(bytes2)
		{
			alias Types[bytes2 / 2] V;
			immutable tmp = *cast(V*) (cast(U*) &src + 1);
		}

		*cast(U*) &dest = *cast(U*) &src;

		static if(bytes2)
			*cast(V*) (cast(U*) &dest + 1) = tmp;
	}
	else
	{
		memmove(&dest, &src, T.sizeof);
	}
}

/// ditto
void rawCopy(T)(in T* src, T* dest, size_t count) nothrow
in { assert(count * T.sizeof / T.sizeof == count); }
body
{
	if(__ctfe)
		rawCopyCTImpl(src, dest, count);
	else
		memmove(dest, src, T.sizeof * count);
}

private void rawCopyCTImpl(T)(const ref T src, ref T dest) pure nothrow
{
	static if(!hasElaborateCopyConstructor!T && isAssignable!T)
	{
		dest = cast(T) src;
	}
	else static if(hasElaborateCopyConstructor!T && isStaticArray!T)
	{
		// We assume static arrays can not overlap in CTFE
		foreach(i, ref el; src)
			rawCopyCTImpl(el, dest[i]);
	}
	else static if(is(T == struct))
	{
		// A struct can be unassignable because of elaborate
		// copy constructor or const fields.
		foreach(i, ref field; src.tupleof)
		{
			alias typeof(field) F;
			static if (is(F U == shared const U))
				alias shared(U) Unqualed;
			else 
				alias Unqual!F Unqualed;
			rawCopyCTImpl(*cast(Unqualed*) &field, *cast(Unqualed*) &dest.tupleof[i]);
		}
	}
	else
	{
		static assert(0, T.stringof ~ " isn't assignable");
	}
}

private void rawCopyCTImpl(T)(in T* src, T* dest, size_t count) pure nothrow
{
	if(count == 1) // As we can't slice non-arrays in CTFE
		rawCopyCTImpl(*src, *dest);
	else if(count != 0)
		foreach(i, ref el; src[0 .. count])
			rawCopyCTImpl(el, dest[i]);
}

unittest
{
	void test(alias f)()
	{
		{
			int src = 1, dest;
			f(src, dest);
			assert(dest == 1);
		}
		{
			static struct S1
			{
				int n;
				int* p;
				const int cn;
				shared int sn;
			}
			int i;
			const S1 src = { 1, &i, 2, 3 };
			S1 dest;
			f(src, dest);
			if(__ctfe) // CTFE pointers @@@BUG@@@ workaround
			{
				assert(dest.p == null, "CTFE bug fixed. Remove this workaround.");
				dest.p = &i;
			}
			assert(dest == S1(1, &i, 2, 3));
		}
		{
			static struct S3
			{
				void opAssign(typeof(this)) { assert(0); }
				this(this) { assert(0); }
				// ~this() { } Can not test destructor because of compiler @@@BUG@@@
				int n;
			}
			S3 src = { 1 }, dest;
			f(src, dest);
			assert(dest.n == 1);

			dest.n = 0;
			f(&src, &dest, 0);
			assert(dest.n == 0);

			f(&src, &dest, 1);
			assert(dest.n == 1);

			S3[2] srcArr, destArr;
			srcArr[0].n = srcArr[1].n = 1; // To not call postblit
			f(srcArr.ptr, destArr.ptr, 2);
			assert(destArr[0].n == 1);
			assert(destArr[1].n == 1);

			static struct S4 { S3 s3; }
			S4 src4, dest4;
			src4.s3.n = 1; // To not call postblit
			f(src4, dest4);
			assert(dest4.s3.n == 1);
		}
	}
	test!rawCopyCTImpl(); // Test CT variant at RT
	test!rawCopy();
	static assert((test!rawCopy(), true));
}

unittest // Optimization for small structs correctness check
{
	static struct S(size_t n)
	{ byte[n] arr; }

	foreach(n; iotaTuple!17)
	{
		S!n src;
		byte[n + 2] destArr;
		auto dest = cast(S!n*) (destArr.ptr + 1);
		foreach(byte i; 0 .. n)
			src.arr[i] = cast(byte) (i + 1);
		rawCopy(src, *dest);
		assert(*dest == src);
		assert(!destArr[0] && !destArr[$ - 1]);
	}
}
