/** Additions to std.typetuple

$(BOOKTABLE Generic tuple manipulation functions,
	$(TR $(TH Category) $(TH Functions))
	$(TR $(TD Creation)
		$(TD
			$(BTREF RetroTuple)
			$(BTREF StrideTuple)
			$(BTREF ChainTuple)
			$(BTREF RoundRobinTuple)
			$(BTREF RadialTuple)
			$(BTREF RepeatTuple)
			$(BTREF ZipTuple)
			$(BTREF iotaTuple)
			$(BTREF IndexedTuple)
			$(BTREF ChunksTuple)
		)
	)
	$(TR $(TD Comparison)
		$(TD
			$(BTREF cmpTuple)
			$(BTREF equalTuple)
		)
	)
	$(TR $(TD Iteration)
		$(TD
			$(BTREF FilterTuple)
			$(BTREF groupTuple)
			$(BTREF JoinTuple)
			$(BTREF MapTuple)
			$(BTREF ReduceTuple)
			$(BTREF UniqTuple)
		)
	)
)

Macros:
BTREF = $(MREF $0)&nbsp;&nbsp;

Copyright: Denis Shelomovskij 2011-2012

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.generictuple;


public import std.typetuple:
	staticIndexOf,
	Erase, EraseAll, NoDuplicates, Replace, ReplaceAll, Reverse,
	MostDerived, DerivedToFront,
	allSatisfy, anySatisfy;

import std.ascii: isDigit;
import std.algorithm: min, max, StoppingPolicy;
import unstd.traits;
import unstd.templates;


/**
Creates a generic tuple out of a sequence of zero or more types, expressions, or aliases.

Example:
---
template MyTemplate(T) { alias T[] MyTemplate; }

alias GenericTuple!(int, 5, "a string", MyTemplate) MyTuple;

MyTuple[0] myVar = MyTuple[1]; // same as `int myVar = 5;`
auto str = MyTuple[2]; // same as `auto str = "a string";`

alias MyTuple[3] Template;
static assert(is(Template!int == int[]));
---
*/
template GenericTuple(Args...)
{
	alias Args GenericTuple;
}

/**
Creates a packed generic tuple out of a sequence of zero or more types, expressions, or aliases.

Packed version doesn't alias itself to its content, i.e. it doesn't auto-unpack.

Example:
---
alias PackedGenericTuple!(long, 3) MyPackedTuple;

MyPackedTuple.Tuple[0] myVar = MyPackedTuple.Tuple[1]; // same as `long myVar = 3;`

template MyTemplate(alias packed)
{ alias packed.Tuple[0][] MyTemplate; }

// It is passed as a single template alias parameter:
static assert(is(MyTemplate!MyPackedTuple == long[]));
---
*/
template PackedGenericTuple(Args...)
{
	/// Use this member of to access its content as a generic tuple.
	alias Args Tuple;

	version(D_Ddoc)
	{
		/**
		Use this member of to access its content as a typetuple.
		Defined if $(D Args) is a typetuple.
		*/
		alias Args Types;

		/**
		Use this member of to access its content as an expression tuple.
		Defined if $(D Args) is an expression tuple.
		*/
		alias Args expressions;
	}
	else
	{
		static if(isTypeTuple!Args)
			alias Args Types;
		else static if(isExpressionTuple!Args)
			alias Args expressions;
	}

	/// Its content length.
	enum length = Tuple.length;

	/// Detect whether it's empty.
	enum empty = !length;

	/// Convenient equality check template. Same as $(MREF equalTuple).
	template equals(A...)
	{ enum equals = equalTuple!(PackedGenericTuple!Args, PackedGenericTuple!A); }

	/// Convenient comparison template. Same as $(MREF cmpTuple).
	template cmp(A...)
	{ enum cmp = cmpTuple!(PackedGenericTuple!Args, PackedGenericTuple!A); }
}

unittest
{
	static assert(isPackedTuple!(PackedGenericTuple!()));

	static assert(is(PackedGenericTuple!int.Types == TypeTuple!int));
	static assert(PackedGenericTuple!3.expressions[0] == 3);
}


/**
Creates a typetuple out of a sequence of zero or more types.
Same as $(D GenericTuple), except it contains only types.

Example:
---
alias TypeTuple!(int, double) IntDouble;

int foo(IntDouble args)  // same as `int foo(int, double)`
{
   return args[0] + cast(int) args[1];
}

alias TypeTuple!(int, double, char) IntDoubleChar;
static assert(is(TypeTuple!(IntDouble, char) == IntDoubleChar));
static assert(is(IntDoubleChar[0 .. 2] == IntDouble));


alias TypeTuple!(int, 5) BadTypeTuple; // error: not a type tuple
---
*/
template TypeTuple(Types...) if(isTypeTuple!Types)
{
	alias Types TypeTuple;
}

unittest
{
	static assert(TypeTuple!().length == 0);
	static assert(!__traits(compiles, TypeTuple!(int, 5)));

	static assert(is(TypeTuple!(int, TypeTuple!()) == TypeTuple!int));
	static assert(is(TypeTuple!(int, TypeTuple!char) == TypeTuple!(int, char)));
	static assert(is(TypeTuple!(int, TypeTuple!(char, bool)) == TypeTuple!(int, char, bool)));
}


/**
Creates a packed typetuple out of a sequence of zero or more types.
Same as $(D PackedGenericTuple), except it contains only types.
*/
template PackedTypeTuple(T...) if(isTypeTuple!T)
{
	alias PackedGenericTuple!T PackedTypeTuple;
}

unittest
{
	static assert(isPackedTuple!(PackedTypeTuple!()));
	static assert(is(PackedTypeTuple!int.Types == TypeTuple!int));
}


/**
Creates an expression tuple out of a sequence of zero or more expressions.
Same as $(D GenericTuple), except it contains only expressions.

Example:
---
alias expressionTuple!(5, 'c', "str") expressions;

typeof(expressions[0]) myVar = expressions[1]; // same as `int myVar = 5;`
auto str = expressions[2]; // same as `auto str = "a string";`

void foo(out typeof(expressions[0 .. 2]) args)  // same as `int foo(out int, out char)`
{
	args[0] = expressions[0] * 2; // same as `5 * 2`
	args[1] = expressions[1] + 1; // same as `'c' + 1`
}

void main()
{
	int i;
	char c;
	foo(i, c);
	assert(i == 10 && c == 'd');
}

alias expressionTuple!(int, 5) badExpressionTuple; // error: not an expression tuple
---
*/
template expressionTuple(expressions...) if(isExpressionTuple!expressions)
{
	alias expressions expressionTuple;
}

unittest
{
	static assert(expressionTuple!().length == 0);
	static assert(PackedGenericTuple!(expressionTuple!(5, 'c', "str")).equals!(5, 'c', "str"));
	static assert(!__traits(compiles, expressionTuple!(int, 5)));
	static assert(!__traits(compiles, expressionTuple!void));
}


/**
Creates a packed expression tuple out of a sequence of zero or more expressions.
Same as $(D PackedGenericTuple), except it contains only expressions.
*/
template packedExpressionTuple(expr...) if(isExpressionTuple!expr)
{
	alias PackedGenericTuple!expr packedExpressionTuple;
}

unittest
{
	static assert(isPackedTuple!(packedExpressionTuple!()));
	static assert(packedExpressionTuple!3.expressions[0] == 3);
}


/**
Creates a generic tuple comprised of elemetns of $(D A) in reverse order.

Applying RetroTuple twice to the same generic tuple equals to
the original generic tuple.

Example:
---
static assert(is(RetroTuple!(int, bool, long) == TypeTuple!(long, bool, int)));
static assert(PackedGenericTuple!(RetroTuple!(1, bool, "x")).equals!("x", bool, 1));
---

Analog of $(PHOBOSREF range, retro) for generic tuples.
*/
template RetroTuple(A...)
{
	static if (A.length == 0)
		alias GenericTuple!() RetroTuple;
	else
		alias GenericTuple!(.RetroTuple!(A[1 .. $]), A[0]) RetroTuple;
}

unittest
{
	static assert(is(RetroTuple!() == GenericTuple!()));
	static assert(is(RetroTuple!int == TypeTuple!int));
	static assert(is(RetroTuple!(int, bool, long) == TypeTuple!(long, bool, int)));
	static assert(PackedGenericTuple!(RetroTuple!(1, bool, "x")).equals!("x", bool, 1));
}


/**
Creates a generic tuple comprised of elemetns of $(D A) taken with stride $(D n).

Applying StrideTuple twice to the same generic tuple equals to applying
StrideTuple with a step that is the product of the two applications.

Example:
---
static assert(is(StrideTuple!(2, ubyte, byte, uint, int, ulong, long) == TypeTuple!(ubyte, uint, ulong)));
static assert(PackedGenericTuple!(StrideTuple!(3, iota)).equals!(1, 4, 7, 10));
---

Analog of $(PHOBOSREF range, stride) for generic tuples
except $(D n) is the first argument.
*/
template StrideTuple(size_t n, A...)
	if(n > 0)
{
	static if(A.length)
		alias GenericTuple!(A[0], StrideTuple!(n, A[min(n, $) .. $])) StrideTuple;
	else
		alias GenericTuple!() StrideTuple;
}

unittest
{
	static assert(is(StrideTuple!1 == GenericTuple!()));
	static assert(is(StrideTuple!(2, ubyte, byte, uint, int, ulong, long) == TypeTuple!(ubyte, uint, ulong)));
	alias iotaTuple!(1, 11) iota;
	static assert(PackedGenericTuple!(StrideTuple!(1, iota)).equals!iota);
	static assert(PackedGenericTuple!(StrideTuple!(2, iota)).equals!(1, 3, 5, 7, 9));
	static assert(PackedGenericTuple!(StrideTuple!(3, iota)).equals!(1, 4, 7, 10));
	static assert(PackedGenericTuple!(StrideTuple!(4, iota)).equals!(1, 5, 9));
}


/**
Creates a generic tuple comprised of all elemetns of packed generic tuples
$(D packedTuples) in sequence.

Example:
---
alias ChainTuple!(packedExpressionTuple!(1, 2, 3), packedExpressionTuple!(4, 5)) chain;
static assert(packedExpressionTuple!chain.equals!(1, 2, 3, 4, 5));
---

Analog of $(PHOBOSREF range, chain) for generic tuples.
*/
template ChainTuple(packedTuples...)
	if(packedTuples.length && allSatisfy!(isPackedTuple, packedTuples))
{
	// Can't use UnaryTemplate!`A.Tuple` because of Issue 9017
	template Func(alias packedTuple) { alias packedTuple.Tuple Func; }
	alias MapTuple!(Func, packedTuples) ChainTuple;
}

unittest
{
	alias ChainTuple!(packedExpressionTuple!(1, 2, 3, 4), packedExpressionTuple!(5, 6), packedExpressionTuple!(), packedExpressionTuple!7) chain;
	static assert(packedExpressionTuple!chain.equals!(1, 2, 3, 4, 5, 6, 7));
}


/**
Creates a generic tuple comprised of all elemetns of packed generic tuples
$(D packedTuples) in an order by analogy with
$(HTTP en.wikipedia.org/wiki/Round-robin_scheduling, Round-robin scheduling).

Example:
---
alias RoundRobinTuple!(packedExpressionTuple!(1, 2, 3), packedExpressionTuple!(10, 20, 30, 40)) roundRobin;
static assert(packedExpressionTuple!roundRobin.equals!(1, 10, 2, 20, 3, 30, 40));
---

Analog of $(PHOBOSREF range, roundRobin) for generic tuples.
*/
template RoundRobinTuple(packedTuples...)
	if(packedTuples.length && allSatisfy!(isPackedTuple, packedTuples))
{
	struct _Empty;
	template pred(alias A) { enum pred = !is(A == _Empty); }
	alias FilterTuple!(pred, ChainTuple!(ZipTuple!(StoppingPolicy.longest, GenericTuple!_Empty, packedTuples))) RoundRobinTuple;
}

unittest
{
	alias RoundRobinTuple!(packedExpressionTuple!(1, 2, 3), packedExpressionTuple!(10, 20, 30, 40)) roundRobin;
	static assert(packedExpressionTuple!roundRobin.equals!(1, 10, 2, 20, 3, 30, 40));
}


/**
Creates a generic tuple comprised of all elemetns of $(D A) which are teken
starting from a given point and progressively extending left and right
from that point. If $(D RadialTupleMiddle) is used or $(D startingIndex)
is $(D -1) it is assumed that no initial point is given and iteration
starts from the middle of $(D A).

Example:
---
static assert(packedExpressionTuple!(RadialTuple!(-1, 1, 2, 3, 4, 5)).equals!(3, 4, 2, 5, 1));
static assert(packedExpressionTuple!(RadialTuple!( 1, 1, 2, 3, 4, 5)).equals!(2, 3, 1, 4, 5));
---

Analog of $(PHOBOSREF range, radial) for generic tuples
except $(D startingIndex) is the first argument and
there is no overload without it.
*/
template RadialTuple(size_t startingIndex, A...)
{
	enum i = (startingIndex == -1 ? (A.length - !!A.length) / 2 : startingIndex) + !!A.length;
	alias RoundRobinTuple!(PackedGenericTuple!(RetroTuple!(A[0 .. i])), PackedGenericTuple!(A[i .. $])) RadialTuple;
}

/// ditto
template RadialTupleMiddle(A...)
{
	alias RadialTuple!(-1, A) RadialTupleMiddle;
}

unittest
{
	static assert(packedExpressionTuple!(RadialTupleMiddle!(1)).equals!1);
	static assert(packedExpressionTuple!(RadialTupleMiddle!(1, 2)).equals!(1, 2));
	static assert(packedExpressionTuple!(RadialTupleMiddle!(1, 2, 3)).equals!(2, 3, 1));
	static assert(packedExpressionTuple!(RadialTupleMiddle!(1, 2, 3, 4)).equals!(2, 3, 1, 4));
	static assert(packedExpressionTuple!(RadialTupleMiddle!(1, 2, 3, 4, 5)).equals!(3, 4, 2, 5, 1));
	static assert(packedExpressionTuple!(RadialTupleMiddle!(1, 2, 3, 4, 5, 6)).equals!(3, 4, 2, 5, 1, 6));
	static assert(packedExpressionTuple!(RadialTuple!(1, 1, 2, 3, 4, 5)).equals!(2, 3, 1, 4, 5));
}


/**
Repeats $(D A) $(D n) times.

Example:
---
static assert(is(RepeatTuple!(2, int) == TypeTuple!(int, int)));
static assert(packedExpressionTuple!(RepeatTuple!(4, 5)).equals!(5, 5, 5, 5));
---

Analog of $(PHOBOSREF array, replicate) and $(PHOBOSREF range, repeat) for generic tuples
except $(D n) is the first argument and there is no overload
without it as tuples can't be infinite.
Also it repeats a generic tuple, not only one value.
*/
template RepeatTuple(size_t n, A...)
{
	static if(n)
		alias GenericTuple!(A, RepeatTuple!(n - 1, A)) RepeatTuple;
	else
		alias GenericTuple!() RepeatTuple;
}

unittest
{
	static assert(is(RepeatTuple!(2, int) == TypeTuple!(int, int)));
	static assert(packedExpressionTuple!(RepeatTuple!(4, 5)).equals!(5, 5, 5, 5));
}


/**
Creates a generic tuple comprised of packed generic tuples comprised of
elemetns of packed generic tuples $(D packedTuples) taken in lockstep.

If $(D stoppingPolicy) is $(D StoppingPolicy.longest) and a tuple is finished
in a lockstep iteration then $(D empty) will be taken.

Example:
---
alias packedExpressionTuple!(1, 2, 3) packed1;
alias PackedTypeTuple!(short, int, long) packed2;
alias ZipTuple!(packed1, packed2) zip;

static assert(zip[0].equals!(1, short));
static assert(zip[1].equals!(2, int));
static assert(zip[2].equals!(3, long))
---

Analog of $(PHOBOSREF range, zip) for generic tuples
except $(D empty) value must be explicitly specified
for $(D StoppingPolicy.longest).
*/
template ZipTuple(StoppingPolicy stoppingPolicy : StoppingPolicy.longest, alias empty, packedTuples...)
{
	alias ZipTupleImpl!(stoppingPolicy, PackedGenericTuple!empty, packedTuples) ZipTuple;
}

/// ditto
template ZipTuple(StoppingPolicy stoppingPolicy : StoppingPolicy.longest, empty, packedTuples...)
{
	alias ZipTupleImpl!(stoppingPolicy, PackedGenericTuple!empty, packedTuples) ZipTuple;
}

/// ditto
template ZipTuple(StoppingPolicy stoppingPolicy, packedTuples...)
	if(stoppingPolicy != StoppingPolicy.longest) // probably a compiler @@@BUG@@@ workaround
{
	alias ZipTupleImpl!(stoppingPolicy, PackedGenericTuple!void, packedTuples) ZipTuple;
}

/// ditto
template ZipTuple(packedTuples...)
	if(packedTuples.length && allSatisfy!(isPackedTuple, packedTuples)) // probably a compiler @@@BUG@@@ workaround
{
	alias ZipTuple!(StoppingPolicy.shortest, packedTuples) ZipTuple;
}

private template ZipTupleImpl(StoppingPolicy stoppingPolicy, alias default_, packedTuples...)
	if(packedTuples.length && allSatisfy!(isPackedTuple, default_, packedTuples) && default_.length == 1)
{
	alias MapTuple!(`A.length`, packedTuples) lengths;

	static if(stoppingPolicy == StoppingPolicy.requireSameLength)
		static assert(allSatisfy!(BindTemplate!(isSame, lengths[0], arg!0), lengths),
			"Inequal-length packed tuples passed to ZipTuple(StoppingPolicy.requireSameLength, ...)");

	template Impl(size_t n, packedTuples...)
	{
		static if(n)
		{
			template tupleFrontOrDefault(alias packedTuple)
			{
				static if(!packedTuple.empty)
					alias packedTuple.Tuple[0 .. 1] tupleFrontOrDefault;
				else
					alias default_.Tuple tupleFrontOrDefault;
			}
			alias GenericTuple!(PackedGenericTuple!(MapTuple!(tupleFrontOrDefault, packedTuples)),
				Impl!(n - 1, MapTuple!(`PackedGenericTuple!(A.Tuple[!A.empty .. $])`, packedTuples))) Impl;
		}
		else
			alias GenericTuple!() Impl;
	}
	static if(packedTuples.length == 1 || stoppingPolicy == StoppingPolicy.requireSameLength)
		enum length = lengths[0];
	else
		enum length = GenericTuple!(min, max)
			[stoppingPolicy == StoppingPolicy.longest](lengths);

	alias Impl!(length, packedTuples) ZipTupleImpl;
}

unittest
{
	alias packedExpressionTuple!(1, 2, 3) packed1;
	alias PackedTypeTuple!(short, int, long) packed2;
	alias ZipTuple!(packed1, packed2) zip;

	static assert(zip[0].equals!(1, short));
	static assert(zip[1].equals!(2, int));
	static assert(zip[2].equals!(3, long));
}

unittest
{
	alias packedExpressionTuple!(iotaTuple!5) packedIota5;
	alias packedExpressionTuple!(iotaTuple!(1, 6)) packedIota16;
	alias packedExpressionTuple!(iotaTuple!(1, 4)) packedIota14;
	alias packedExpressionTuple!(iotaTuple!(1, 8)) packedIota18;

	void test(size_t length, size_t filledLength, size_t longerIdx, zip...)()
	{
		static assert(zip.length == length);
		foreach (i, e; zip)
			static assert(e.Tuple[0] == (i < filledLength || longerIdx == 0 ? i : -2) &&
				e.Tuple[1] == (i < filledLength || longerIdx == 1 ? i + 1 : -3));
	}

	with(StoppingPolicy) foreach(stoppingPolicy; expressionTuple!(shortest, longest, requireSameLength))
	{
		static if(stoppingPolicy == longest)
			alias void def;
		else
			alias expressionTuple!() def;

		alias ZipTuple!(stoppingPolicy, def, packedIota5, packedIota16) zip;
		test!(5, 5, -1, zip)();
	}

	static assert(!__traits(compiles, ZipTuple!(StoppingPolicy.requireSameLength, packedIota5, packedIota14)));
	static assert(!__traits(compiles, ZipTuple!(StoppingPolicy.requireSameLength, packedIota5, packedIota18)));

	test!(3, 3, -1, ZipTuple!(packedIota5, packedIota14))();
	test!(5, 5, -1, ZipTuple!(packedIota5, packedIota18))();

	test!(5, 3, 0, ZipTuple!(StoppingPolicy.longest, -3, packedIota5, packedIota14))();
	test!(7, 5, 1, ZipTuple!(StoppingPolicy.longest, -2, packedIota5, packedIota18))();
}


/**
Returns expression tuple with elements going through the numbers $(D begin), $(D begin +
step), $(D begin + 2 * step), $(D ...), up to and excluding $(D end).
The two-arguments version has $(D step = 1).
The one-argument version also has $(D begin = 0).
If $(D begin < end && step < 0) or $(D begin > end && step > 0) or $(D begin == end),
then an empty tuple is returned.

Example:
---
int res;
foreach(i; iotaTuple!5) // same as res += foo!1(); res += foo!3();
	static if(i & 1)
		res += foo!i();
---

Tip:
This is a convenient way to create a CT analog of
$(HTTP dlang.org/statement.html#ForeachRangeStatement, Foreach Range Statement).

Analog of $(PHOBOSREF range, iota) for generic tuples.
*/
template iotaTuple(alias begin, alias end, alias step)
{
	alias iotaTupleImpl!(CommonType!(typeof(begin), typeof(end), typeof(step)), begin, end, step) iotaTuple;
}

/// ditto
template iotaTuple(alias begin, alias end)
{
	alias iotaTupleImpl!(CommonType!(typeof(begin), typeof(end)), begin, end, 1) iotaTuple;
}

/// ditto
template iotaTuple(alias end)
{
	alias iotaTupleImpl!(typeof(end), 0, end, 1) iotaTuple;
}

private template iotaTupleImpl(T, T begin, T end, T step)
	if(isIntegral!T || isFloatingPoint!T && step)
{
	static if(begin < end && step < 0 || begin > end && step > 0 || begin == end)
		alias expressionTuple!() iotaTupleImpl;
	else static if(step)
		alias expressionTuple!(begin, iotaTupleImpl!(T, begin + step, end, step)) iotaTupleImpl;
	else
		static assert(0, "iotaTuple: `step` can't be zero for nonequal `begin` and `end`");
}

unittest
{
	static assert(iotaTuple!0.length == 0);
	static assert(iotaTuple!(10, 1).length == 0);
	static assert(iotaTuple!(1, 10, -1).length == 0);
	static assert(iotaTuple!(2, 2, 0).length == 0);
	static assert(!__traits(compiles, iotaTuple!(1, 2, 0)));

	static assert(packedExpressionTuple!(iotaTuple!1).equals!0);
	static assert(packedExpressionTuple!(iotaTuple!3).equals!(0, 1, 2));
	static assert(packedExpressionTuple!(iotaTuple!(1.0, 3)).equals!(1.0, 2.0));
	static assert(packedExpressionTuple!(iotaTuple!(1, 3.1f)).equals!(1.0, 2.0, 3.0));
	static assert(packedExpressionTuple!(iotaTuple!(3, 0, -1)).equals!(3, 2, 1));
	static assert(packedExpressionTuple!(iotaTuple!(3, 2, -.5)).equals!(3.0, 2.5));
}


/**
Creates a generic tuple comprised of elemetns of packed generic tuple
$(D packedSourceTuple) reordered according to packed expression tuple
$(D packedIndicesTuple). $(D packedIndicesTuple) may include only a subset
of the elements of $(D packedSourceTuple) and may also repeat elements.

Example:
---
alias IndexedTuple!(PackedTypeTuple!(short, int, long, double),
                    packedExpressionTuple!(1, 0, 2, 2)) indexed;
static assert(is(indexed == TypeTuple!(int, short, long, long)));
---

Analog of $(PHOBOSREF range, indexed) for generic tuples.
*/
template IndexedTuple(alias packedSourceTuple, alias packedIndicesTuple)
	if(isPackedTuple!packedSourceTuple && isPackedTuple!packedIndicesTuple)
{
	template Func(A...) if(A.length == 1)
	{ alias packedSourceTuple.Tuple[A[0] .. A[0] + 1] Func; }
	alias MapTuple!(Func, packedIndicesTuple.Tuple) IndexedTuple;
}

unittest
{
	alias IndexedTuple!(PackedTypeTuple!(short, int, long, double), packedExpressionTuple!(1, 0, 2, 2)) indexed;
	static assert(is(indexed == TypeTuple!(int, short, long, long)));

	alias IndexedTuple!(packedExpressionTuple!(1, 2, 3, 4, 5), packedExpressionTuple!(4, 3, 1, 2, 0, 4)) indexed2;
	static assert(packedExpressionTuple!indexed2.equals!(5, 4, 2, 3, 1, 5));
}


/**
Creates a generic tuple comprised of packed generic tuples comprised of
fixed-sized chunks of size $(D chunkSize) of $(D A).

If $(D A.length) is not evenly divisible by $(D chunkSize), the last
packed generic tuple will contain fewer than $(D chunkSize) elements.

Example:
---
alias ChunksTuple!(4,  1, 2, 3, 4, 5, 6, byte, short, int, long) chunks;
static assert(chunks[0].equals!(1, 2, 3, 4));
static assert(chunks[1].equals!(5, 6, byte, short));
static assert(chunks[2].equals!(int, long));
---

Analog of $(PHOBOSREF range, chunks) for generic tuples
except $(D chunkSize) is the first argument.
*/
template ChunksTuple(size_t chunkSize, A...)
{
	static if(A.length > chunkSize)
		alias GenericTuple!(PackedGenericTuple!(A[0 .. chunkSize]),
			ChunksTuple!(chunkSize, A[chunkSize .. $])) ChunksTuple;
	else
		alias GenericTuple!(PackedGenericTuple!A) ChunksTuple;
}

unittest
{
	alias ChunksTuple!(4,  1, 2, 3, 4, 5, 6, byte, short, int, long) chunks;
	static assert(chunks[0].equals!(1, 2, 3, 4));
	static assert(chunks[1].equals!(5, 6, byte, short));
	static assert(chunks[2].equals!(int, long));
}


/**
Performs $(HTTP en.wikipedia.org/wiki/Three-way_comparison, three-way
lexicographical comparison) on two packed generic tuples
according to predicate $(D pred).

Iterating $(D packedTuple1) and $(D packedTuple2) in lockstep, cmpTuple
compares each element $(D A1) of $(D packedTuple1) with the corresponding
element $(D A2) in $(D packedTuple2).
If $(D Inst!(binaryPred!pred, A1, A2)), $(D cmp) returns a negative value.
If $(D Inst!(binaryPred!pred, A2, A1)), $(D cmp) returns a positive value.
If one of the tuples has been finished, $(D cmp) returns a negative value
if $(D packedTuple1) has fewer elements than $(D packedTuple2), a positive
value if $(D packedTuple1) has more elements than $(D packedTuple2), and
$(D 0) if the tuples have the same number of elements.

Example:
---
static assert(cmpTuple!(packedExpressionTuple!0, packedExpressionTuple!0) == 0);
static assert(cmpTuple!(packedExpressionTuple!"a", packedExpressionTuple!"ab") < 0);
static assert(cmpTuple!(`T.sizeof < U.sizeof`, PackedTypeTuple!int, PackedTypeTuple!long) < 0);
---

Analog of $(PHOBOSREF algorithm, cmp) for generic tuples.
*/
template cmpTuple(alias pred, alias packedTuple1, alias packedTuple2)
	if(isPackedTuple!packedTuple1 && isPackedTuple!packedTuple2)
{
	alias binaryPred!pred predTemplate;

	static if (packedTuple1.empty)
		enum cmpTuple = -cast(int) !packedTuple2.empty;
	else static if (packedTuple2.empty)
		enum cmpTuple = cast(int) !packedTuple1.empty;
	else static if (predTemplate!(packedTuple1.Tuple[0], packedTuple2.Tuple[0]))
		enum cmpTuple = -1;
	else static if (predTemplate!(packedTuple2.Tuple[0], packedTuple1.Tuple[0]))
		enum cmpTuple = 1;
	else
		enum cmpTuple = cmpTuple!(predTemplate, PackedGenericTuple!(packedTuple1.Tuple[1 .. $]), PackedGenericTuple!(packedTuple2.Tuple[1 .. $]));
}

/// ditto
template cmpTuple(alias packedTuple1, alias packedTuple2)
{
	enum cmpTuple = cmpTuple!(`a < b`, packedTuple1, packedTuple2);
}

unittest
{
	static assert(cmpTuple!(PackedGenericTuple!(), PackedGenericTuple!()) == 0);
	static assert(cmpTuple!(packedExpressionTuple!0, packedExpressionTuple!0) == 0);
	static assert(cmpTuple!(packedExpressionTuple!0, packedExpressionTuple!1) < 0);
	static assert(cmpTuple!(packedExpressionTuple!0, packedExpressionTuple!(0, 0)) < 0);
	static assert(cmpTuple!(packedExpressionTuple!(0, 0), packedExpressionTuple!0) > 0);
	static assert(cmpTuple!(packedExpressionTuple!1, packedExpressionTuple!(0, 0)) > 0);

	static assert(cmpTuple!(packedExpressionTuple!"a", packedExpressionTuple!"a") == 0);
	static assert(cmpTuple!(packedExpressionTuple!"a", packedExpressionTuple!"ab") < 0);
	static assert(cmpTuple!(packedExpressionTuple!"b", packedExpressionTuple!"ab") > 0);

	static assert(cmpTuple!(`T.sizeof < U.sizeof`, PackedTypeTuple!int, PackedTypeTuple!long) < 0);
}


/**
Detect whether two packed generic tuples $(D packedTuple1) and $(D packedTuple2)
elements are equal according to binary predicate $(D pred).

$(D isSame) is used if no predicacte specified.

Example:
---
static assert( equalTuple!(packedExpressionTuple!(0, 1), packedExpressionTuple!(iotaTuple!2)));
static assert( equalTuple!(PackedGenericTuple!(int, "a"), PackedGenericTuple!(int, "a")));

static assert( equalTuple!(`true`, packedExpressionTuple!1, PackedTypeTuple!int));
static assert(!equalTuple!(`true`, packedExpressionTuple!1, packedExpressionTuple!()));
---

Analog of $(PHOBOSREF algorithm, equal) for generic tuples.
*/
template equalTuple(alias pred, alias packedTuple1, alias packedTuple2)
	if(isPackedTuple!packedTuple1 && isPackedTuple!packedTuple2)
{
	alias binaryPred!pred predTemplate;

	template instForPackedTuple(alias packedTuple)
		if(isPackedTuple!packedTuple && packedTuple.length == 2)
	{
		enum instForPackedTuple = predTemplate!(packedTuple.Tuple);
	}

	static if(packedTuple1.length == packedTuple2.length)
		enum equalTuple = allSatisfy!(instForPackedTuple, ZipTuple!(packedTuple1, packedTuple2));
	else
		enum equalTuple = false;
}

/// ditto
template equalTuple(alias packedTuple1, alias packedTuple2)
{
	enum equalTuple = equalTuple!(isSame, packedTuple1, packedTuple2);
}

unittest
{
	static assert( equalTuple!(PackedGenericTuple!(), PackedGenericTuple!()));
	static assert( equalTuple!(packedExpressionTuple!0, packedExpressionTuple!0));
	static assert(!equalTuple!(packedExpressionTuple!0, PackedTypeTuple!int));
	static assert(!equalTuple!(packedExpressionTuple!0, packedExpressionTuple!(0, 1)));
	static assert( equalTuple!(packedExpressionTuple!(0, 1), packedExpressionTuple!(iotaTuple!2)));
	static assert( equalTuple!(PackedGenericTuple!(int, "a"), PackedGenericTuple!(int, "a")));

	static assert(!equalTuple!(`true`, packedExpressionTuple!1, packedExpressionTuple!()));
	static assert( equalTuple!(`true`, packedExpressionTuple!1, PackedTypeTuple!int));
}


/**
Creates a generic tuple comprised of elemetns of $(D A) for which a unary
predicate $(D pred) is $(D true).

Example:
----
import std.traits;

static assert(is(FilterTuple!(isNumeric, int, void, immutable short, char) ==
              TypeTuple!(int, immutable short)));

static assert(is(FilterTuple!(`__traits(isUnsigned, T)`, int, size_t, void, ushort, char) ==
              TypeTuple!(size_t, ushort, char)));
----

Analog of $(PHOBOSREF algorithm, filter) for generic tuples.
*/
template FilterTuple(alias pred, A...)
{
	alias UnaryTemplate!pred PredTemplate;

	template func(A...) if(A.length == 1)
	{ alias A[0 .. PredTemplate!(A[0])] func; }

	alias MapTuple!(func, A) FilterTuple;
}

unittest
{
	import std.traits;

	static assert(is(FilterTuple!(isNumeric, int, size_t, void, immutable short, char) ==
		TypeTuple!(int, size_t, immutable short)));

	static assert(is(FilterTuple!(`__traits(isUnsigned, T)`, int, size_t, void, immutable ushort, char) ==
		TypeTuple!(size_t, immutable ushort, char)));
}


/**
Similarly to $(MREF UniqTuple), creates a generic tuple comprised of packed generic tuples comprised of unique
consecutive elemetns of $(D A) and counts of equivalent elements seen.

Equivalence of elements is assessed by using a binary predicate $(D pred).

Example:
----
alias GenericTuple!(1, 2, 2, 2, "x", "x", int, 1, 1) tuple;

alias groupTuple!(isSame, tuple) group;
static assert(group.length == 5);
static assert(group[0].equals!(1, 1));
static assert(group[1].equals!(2, 3));
static assert(group[2].equals!("x", 2));
static assert(group[3].equals!(int, 1));
static assert(group[4].equals!(1, 2));

alias groupTuple!(TemplateNot!isSame, tuple) group2;
static assert(group2.length == 3);
static assert(group2[0].equals!(1, 7));
static assert(group2[1].equals!(1, 1));
static assert(group2[2].equals!(1, 1));
----

Analog of $(PHOBOSREF algorithm, group) for generic tuples
except $(D pred) must be explicitly specified.
*/
template groupTuple(alias pred, A...)
{
	alias binaryPred!pred predTemplate;

	template impl(size_t count, A...) if(A.length >= 1)
	{
		static if(A.length == 1 || !predTemplate!(A[0], A[1]))
		{
			alias PackedGenericTuple!(A[0], count) curr;

			static if(A.length == 1)
				alias GenericTuple!(curr) impl;
			else
				alias GenericTuple!(curr, impl!(1, A[1], A[2 .. $])) impl;
		}
		else
			alias impl!(count + 1, A[0], A[2 .. $]) impl;
	}

	static if(A.length)
		alias impl!(1, A) groupTuple;
	else
		alias GenericTuple!() groupTuple;
}

unittest
{
	static assert(groupTuple!isSame.length == 0);

	alias GenericTuple!(1, 2, 2, 2, "x", "x", int, 1, 1) tuple;

	alias groupTuple!(isSame, tuple) group;
	static assert(group.length == 5);
	static assert(group[0].equals!(1, 1));
	static assert(group[1].equals!(2, 3));
	static assert(group[2].equals!("x", 2));
	static assert(group[3].equals!(int, 1));
	static assert(group[4].equals!(1, 2));

	alias groupTuple!(TemplateNot!isSame, tuple) group2;
	static assert(group2.length == 3);
	static assert(group2[0].equals!(1, 7));
	static assert(group2[1].equals!(1, 1));
	static assert(group2[2].equals!(1, 1));
}


/**
Creates a generic tuple comprised of packed generic tuples $(D packedTuples)
generic tuples joined together using packed generic tuple $(D packedSeparatorTuple)
as a separator.

Example:
----
alias packedExpressionTuple!"+" sep;
alias PackedTypeTuple!(void, int) part1;
alias packedExpressionTuple!0 part2;
static assert(PackedGenericTuple!(JoinTuple!(sep, part1, part2)).equals!(void, int, "+", 0));
----

Analog of $(PHOBOSREF array, join) and $(PHOBOSREF algorithm, joiner) for generic tuples.
*/
template JoinTuple(alias packedSeparatorTuple, packedTuples...)
	if(allSatisfy!(isPackedTuple, packedSeparatorTuple, packedTuples))
{
	template Prefix(alias packedTuple)
	{ alias ChainTuple!(packedSeparatorTuple, packedTuple) Prefix; }

	static if(packedTuples.length)
		alias GenericTuple!(packedTuples[0].Tuple, MapTuple!(Prefix, packedTuples[1 .. $])) JoinTuple;
	else
		alias GenericTuple!() JoinTuple;
}

unittest
{
	alias packedExpressionTuple!"+" sep;
	alias PackedTypeTuple!(void, int) part1;
	alias packedExpressionTuple!0 part2;

	static assert(JoinTuple!sep.length == 0);
	static assert(is(JoinTuple!(sep, part1) == TypeTuple!(void, int)));
	static assert(PackedGenericTuple!(JoinTuple!(sep, part1, part2)).equals!(void, int, "+", 0));
}


/**
Creates a generic tuple comprised of results of applying unary
template $(D Func) to elemetns of $(D A) consecutively.

Example:
---
alias MapTuple!(`a * a`, iotaTuple!4) squares;
static assert(packedExpressionTuple!squares.equals!(0, 1, 4, 9));

static assert(is(MapTuple!(`T[]`, int, long) == TypeTuple!(int[], long[])));
---

Analog of $(PHOBOSREF algorithm, map) for generic tuples
except $(D Func) can return any count of elements.
*/
template MapTuple(alias Func, A...)
{
	alias UnaryTemplate!Func FuncTemplate;

	static if (A.length)
		alias GenericTuple!(FuncTemplate!(A[0]), MapTuple!(FuncTemplate, A[1 .. $])) MapTuple;
	else
		alias GenericTuple!() MapTuple;
}

unittest
{
	static assert(MapTuple!`1`.length == 0);
	static assert(packedExpressionTuple!(MapTuple!(`1`, const int)).equals!1);
	static assert(is(MapTuple!(Unqual, int, immutable int) == TypeTuple!(int, int)));
	static assert(is(MapTuple!(`T[]`, int, long) == TypeTuple!(int[], long[])));
	alias MapTuple!(`a * a`, iotaTuple!4) squares;
	static assert(packedExpressionTuple!squares.equals!(0, 1, 4, 9));
}


/**
The instantiation of $(D ReduceTuple!(Func, init, A)) first lets $(D result)
be $(D init). Then, for each element $(D x) in $(D A) sequentially, it lets $(D result)
be $(D Inst!(BinaryTemplate!Func, result, x)). Finally, $(D result) is returned.

Example:
----
static assert(ReduceTuple!(`a + U.sizeof`, 0, bool, short, int) == 1 + 2 + 4);
static assert(is(ReduceTuple!(`Select!(T.sizeof > U.sizeof, T, U)`, void, bool, long, int) == long));
----

Analog of $(PHOBOSREF algorithm, reduce) for generic tuples
except there is no overload with multiple functions.
*/
template ReduceTuple(alias Func, alias init, A...)
{
	alias init Init;
	mixin ReduceTupleImpl;
	alias Res ReduceTuple;
}

template ReduceTuple(alias Func, Init, A...)
{
	mixin ReduceTupleImpl;
	alias Res ReduceTuple;
}

private mixin template ReduceTupleImpl()
{
	alias BinaryTemplate!Func FuncTemplate;

	static if(A.length)
		alias .ReduceTuple!(FuncTemplate, FuncTemplate!(Init, A[0]), A[1 .. $]) Res;
	else
		alias Init Res;
}

unittest
{
	static assert(is(ReduceTuple!(`true`, void) == void));
	static assert(ReduceTuple!(`true`, 0) == 0);
	static assert(ReduceTuple!(`true`, void, int) == true);
	static assert(ReduceTuple!(`a + U.sizeof`, 0, bool, short, int) == 1 + 2 + 4);
	static assert(is(ReduceTuple!(`Select!(T.sizeof > U.sizeof, T, U)`, void, bool, long, int) == long));
}


/**
Creates a generic tuple comprised of unique consecutive elemetns of $(D A).

Equivalence of elements is assessed by using a binary predicate $(D pred).

Example:
----
alias expressionTuple!(1, 2, 2, 2, 3, 3, 4, 1, 1) expr;
static assert(packedExpressionTuple!(UniqTuple!(`a == b`, expr)).equals!(1, 2, 3, 4, 1));
static assert(packedExpressionTuple!(UniqTuple!(`a != b`, expr)).equals!(1, 1, 1));
----

Analog of $(PHOBOSREF algorithm, uniq) for generic tuples
except $(D pred) must be explicitly specified.
*/
template UniqTuple(alias pred, A...)
{
	alias binaryPred!pred predTemplate;

	template Impl(A...) if(A.length >= 1)
	{
		static if(A.length >= 2)
		{
			static if(predTemplate!(A[0], A[1]))
				alias Impl!(A[0], A[2 .. $]) Impl;
			else
				alias GenericTuple!(A[1], Impl!(A[1], A[2 .. $])) Impl;
		}
		else
			alias A[1 .. $] Impl;
	}

	static if(A.length <= 1)
		alias A UniqTuple;
	else
		alias GenericTuple!(A[0], Impl!(A[0], A[1 .. $])) UniqTuple;
}

unittest
{
	alias expressionTuple!(1, 2, 2, 2, 3, 3, 4, 1, 1) expr;
	static assert(packedExpressionTuple!(UniqTuple!(`a == b`, expr)).equals!(1, 2, 3, 4, 1));
	static assert(packedExpressionTuple!(UniqTuple!(`a != b`, expr)).equals!(1, 1, 1));
}

//  internal templates from std.typetuple:

private template isSame(ab...)
    if (ab.length == 2)
{
    static if (__traits(compiles, expectType!(ab[0]),
                                  expectType!(ab[1])))
    {
        enum isSame = is(ab[0] == ab[1]);
    }
    else static if (!__traits(compiles, expectType!(ab[0])) &&
                    !__traits(compiles, expectType!(ab[1])) &&
                     __traits(compiles, expectBool!(ab[0] == ab[1])))
    {
        static if (!__traits(compiles, &ab[0]) ||
                   !__traits(compiles, &ab[1]))
            enum isSame = (ab[0] == ab[1]);
        else
            enum isSame = __traits(isSame, ab[0], ab[1]);
    }
    else
    {
        enum isSame = __traits(isSame, ab[0], ab[1]);
    }
}
private template expectType(T) {}
private template expectBool(bool b) {}
