/** Additions to std.math.

Copyright: Denis Shelomovskij 2011-2012

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.math;


public import std.math;

import core.bitop: bsr;


@safe pure nothrow:


/// Returns $(D true) iff $(D n) is a power of 2
bool isPowerOf2(uint n)
in { assert(n > 0); }
body { return !((n - 1) & n); }

unittest
{
	static assert( isPowerOf2(1));
	static assert( isPowerOf2(2));
	static assert(!isPowerOf2(3));
	static assert( isPowerOf2(4));
	static assert(!isPowerOf2(5));
}


/// Returns largest power of 2 which <= $(D n). $(D n) must be non-zero.
uint roundDownToPowerOf2(uint n)
in { assert(n > 0); }
body { return 1 << bsr(n); }

unittest
{
	alias roundDownToPowerOf2 down;
	static assert(!__traits(compiles, { enum e = down(0); }));
	static assert(down(1) == 1);
	static assert(down(2) == 2 && down(3) == 2);
	static assert(down(4) == 4 && down(5) == 4);
	static assert(down(6) == 4 && down(7) == 4);
	static assert(down(8) == 8 && down(9) == 8);
}


/// Returns smallest power of 2 which >= $(D n). $(D n) must be non-zero.
uint roundUpToPowerOf2(uint n)
in { assert(n > 0); }
body { return 1 << (bsr(n) + !isPowerOf2(n)); }

unittest
{
	alias roundUpToPowerOf2 up;
	static assert(!__traits(compiles, { enum e = up(0); }));
	static assert(up(1) == 1);
	static assert(up(2) == 2);
	static assert(up(3) == 4 && up(4) == 4);
	static assert(up(5) == 8 && up(6) == 8);
	static assert(up(7) == 8 && up(8) == 8);
}


/// Aligns $(D n) up or down. $(D alignment) must be power of 2.
uint alignDown()/*@@@BUG1528@@@ workaround*/(uint alignment, uint n)
in { assert(isPowerOf2(alignment)); }
body
{
	return n & ~(alignment - 1); // alignment - 1: 0b11, 0b111, ...
}

/// ditto
uint alignDown(uint alignment)(uint n) if(isPowerOf2(alignment))
{ return alignDown(alignment, n); }

/// ditto
uint alignUp()/*@@@BUG1528@@@ workaround*/(uint alignment, uint n)
in { assert(isPowerOf2(alignment)); }
body
{
	return alignDown(alignment, n + alignment - 1);	
}

/// ditto
uint alignUp(uint alignment)(uint n) if(isPowerOf2(alignment))
{ return alignUp(alignment, n); }

unittest
{
	static assert(!__traits(compiles, alignDown!0(1)));
	static assert(!__traits(compiles, alignUp!  0(1)));
	static assert(!__traits(compiles, { enum e = alignDown(0, 1); }));
	static assert(!__traits(compiles, { enum e = alignUp  (0, 1); }));

	import unstd.generictuple: iotaTuple;
	foreach(n; iotaTuple!5)
	{
		static assert(alignDown!1(n) == n);
		static assert(alignUp!1(n) == n);
		static assert(alignDown(1, n) == n);
		static assert(alignUp(1, n) == n);
	}

	import unstd.generictuple: expressionTuple;
	foreach(alignment; expressionTuple!(2, 4, 8, 16))
	{
		static assert(!__traits(compiles, alignDown!(alignment + 1)(1)));
		static assert(!__traits(compiles, alignUp!(alignment + 1)(1)));
		
		alias alignDown!alignment down;
		alias alignUp!alignment up;
		static assert(down(0) == 0 && up(0) == 0);

		static assert(down(1) == 0);
		static assert(down(alignment - 1) == 0);
		static assert(down(alignment) == alignment);
		static assert(down(alignment + 1) == alignment);

		static assert(up(1) == alignment);
		static assert(up(alignment - 1) == alignment);
		static assert(up(alignment) == alignment);
		static assert(up(alignment + 1) == alignment * 2);
	}

	static assert(alignDown!2(uint.max) == uint.max - 1);
	static assert(alignDown!16(uint.max) == uint.max - 15);
	static assert(alignUp!2(uint.max - 1) == uint.max - 1);
	static assert(alignUp!2(uint.max) == 0);
}
