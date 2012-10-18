/** Additions to std.math.

Copyright: Denis Shelomovskij 2011-2012

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.math;


public import std.math;

import core.bitop: bsr;


/// Returns $(D true) iff $(D n) is a power of 2
bool isPowerOf2(uint n)
in { assert(n > 0); }
body { return !((n - 1) & n); }

unittest
{
	assert( isPowerOf2(1));
	assert( isPowerOf2(2));
	assert(!isPowerOf2(3));
	assert( isPowerOf2(4));
	assert(!isPowerOf2(5));
}


/// Returns smallest power of 2 which >= $(D n)
uint toPowerOf2(uint n)
in { assert(n > 0); }
body { return 1 << (bsr(n) + !isPowerOf2(n)); }

unittest
{
	assert(toPowerOf2(1) == 1);
	assert(toPowerOf2(2) == 2);
	assert(toPowerOf2(3) == 4);
	assert(toPowerOf2(4) == 4);
	assert(toPowerOf2(5) == 8);
}
