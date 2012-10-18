/** Additions to std.math.

Copyright: Denis Shelomovskij 2011-2012

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

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


/// Returns smallest power of 2 which >= $(D n)
uint roundUpToPowerOf2(uint n)
in { assert(n > 0); }
body { return 1 << (bsr(n) + !isPowerOf2(n)); }

unittest
{
	static assert(roundUpToPowerOf2(1) == 1);
	static assert(roundUpToPowerOf2(2) == 2);
	static assert(roundUpToPowerOf2(3) == 4);
	static assert(roundUpToPowerOf2(4) == 4);
	static assert(roundUpToPowerOf2(5) == 8);
}
